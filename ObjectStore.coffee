###*
	@fileoverview Wrapper for an IndexedDB object store.
###

goog.provide 'com.tripomatic.ObjectStore'

goog.require 'goog.async.Deferred'
goog.require 'com.tripomatic.db.Cursor'
goog.require 'com.tripomatic.db.Error'
goog.require 'com.tripomatic.db.Index'
goog.require 'goog.debug'
goog.require 'goog.events'

###*
	Creates an IDBObjectStore wrapper object. Object stores have methods for
	storing and retrieving records, and are accessed through a transaction
	object. They also have methods for creating indexes associated with the
	object store. They can only be created when setting the version of the
	database. Should not be created directly, access object stores through
	transactions.
	@see com.tripomatic.db.IndexedDb#setVersion
	@see com.tripomatic.db.Transaction#objectStore

	@param {!IDBObjectStore} store The backing IndexedDb object.
	@constructor

	TODO(user): revisit msg in exception and errors in this class. In newer
	    Chrome (v22+) the error/request come with a DOM error string that is
	    already very descriptive.
	@final
###
class com.tripomatic.db.ObjectStore

	constructor: (store) ->
		###*
			Underlying IndexedDB object store object.
			
			@type {!IDBObjectStore}
			@private
		###
		this.store_ = store;


	###*
		@return {string} The name of the object store.
	###
	getName: () ->
		return @store_.name



	###*
		Helper function for put and add.

		@param {string} fn Function name to call on the object store.
		@param {string} msg Message to give to the error.
		@param {*} value Value to insert into the object store.
		@param {IDBKeyType=} opt_key The key to use.
		@return {!goog.async.Deferred} The resulting deferred request.
		@private
	###
	insert_: (fn, msg, value, opt_key) ->
		# TODO(user): refactor wrapping an IndexedDB request in a Deferred by
		# creating a higher-level abstraction for it (mostly affects here and
		# com.tripomatic.db.Index)
		d = new goog.async.Deferred
		try
			#put or add with (value, undefined) throws an error, so we need to check
			#for undefined ourselves
			if opt_key
				request = @store_[fn](value, opt_key)
			else
				request = @store_[fn](value)
		catch ex
			msg += goog.debug.deepExpose value
			if opt_key
				msg += ', with key ' + goog.debug.deepExpose opt_key
			d.errback com.tripomatic.Error.fromException(ex, msg)
			return d
		request.onsuccess = (ev) ->
			d.callback()
		request.onerror = (ev) =>
			msg += goog.debug.deepExpose(value);
			if opt_key
				msg += ', with key ' + goog.debug.deepExpose opt_key
			d.errback com.tripomatic.Error.fromRequest(ev.target, msg)
		return d

	###*
		Adds an object to the object store. Replaces existing objects with the
		same key.

		@param {*} value The value to put.
		@param {IDBKeyType=} opt_key The key to use. Cannot be used if the
		    keyPath was specified for the object store. If the keyPath was not
		    specified but autoIncrement was not enabled, it must be used.
		@return {!goog.async.Deferred} The deferred put request.
	###
	put: (value, opt_key) ->
		return @insert_ 'put', 'putting into ' + @getName() + ' with value', value, opt_key

	###*
		Adds an object to the object store. Requires that there is no object with
		the same key already present.

		@param {*} value The value to add.
		@param {IDBKeyType=} opt_key The key to use. Cannot be used if the
		    keyPath was specified for the object store. If the keyPath was not
		    specified but autoIncrement was not enabled, it must be used.
		@return {!goog.async.Deferred} The deferred add request.
	###
	add: (value, opt_key) ->
		return @insert_ 'add', 'adding into ' + @getName() + ' with value ', value, opt_key

	###*
		Removes an object from the store. No-op if there is no object present with
		the given key.

		@param {IDBKeyType} key The key to remove objects under.
		@return {!goog.async.Deferred} The deferred remove request.
	###
	remove: (key) ->
		d = new goog.async.Deferred
		try
			request = @store_['delete'](key)
		catch err
			msg = 'removing from ' + @getName() + ' with key ' + goog.debug.deepExpose key
			d.errback com.tripomatic.db.Error.fromException(err, msg) 
			return d
		request.onsuccess = (ev) ->
			d.callback();
		request.onerror = (ev) =>
			msg = 'removing from ' + @getName() + ' with key ' + goog.debug.deepExpose key
			d.errback com.tripomatic.db.Error.fromRequest(ev.target, msg)
		return d

	###*
		Gets an object from the store. If no object is present with that key
		the result is {@code undefined}.

		@param {IDBKeyType} key The key to look up.
		@return {!goog.async.Deferred} The deferred get request.
	###
	get: (key) ->
		d = new goog.async.Deferred
		try
			request = @store_.get(key);
		catch err
			msg = 'getting from ' + @getName() + ' with key ' +	goog.debug.deepExpose(key)
			d.errback com.tripomatic.db.Error.fromException(err, msg)
			return d
		request.onsuccess = (ev) ->
			d.callback ev.target.result
		request.onerror = (ev) =>
			msg = 'getting from ' + @getName() + ' with key ' + goog.debug.deepExpose key
			d.errback com.tripomatic.db.Error.fromRequest(ev.target, msg)
		return d

	###*
		Gets all objects from the store and returns them as an array.

		@param {!com.tripomatic.db.KeyRange=} opt_range The key range. If undefined iterates
		    over the whole object store.
		@param {!com.tripomatic.db.Cursor.Direction=} opt_direction The direction. If undefined
		    moves in a forward direction with duplicates.
		@return {!goog.async.Deferred} The deferred getAll request.
	###
	getAll: (opt_range, opt_direction) ->
		d = new goog.async.Deferred()
		try
			cursor = @openCursor opt_range, opt_direction
		catch err
			d.errback err
			return d

		result = []
		key = goog.events.listen cursor, com.tripomatic.db.Cursor.EventType.NEW_DATA, () ->
			result.push cursor.getValue()
			cursor.next()

		goog.events.listenOnce cursor, [com.tripomatic.db.Cursor.EventType.ERROR, com.tripomatic.db.Cursor.EventType.COMPLETE], (evt) ->
			cursor.dispose()
			if  evt.type == com.tripomatic.db.Cursor.EventType.COMPLETE 
				d.callback result
			else
				d.errback()
		return d

	###*
		Opens a cursor over the specified key range. Returns a cursor object which is
		able to iterate over the given range.

		Example usage:

		<code>
		  var cursor = objectStore.openCursor(com.tripomatic.db.Range.bound('a', 'c'));

		  var key = goog.events.listen(
		      cursor, com.tripomatic.db.Cursor.EventType.NEW_DATA, function() {
		    // Do something with data.
		    cursor.next();
		  });

		  goog.events.listenOnce(
		      cursor, com.tripomatic.db.Cursor.EventType.COMPLETE, function() {
		    // Clean up listener, and perform a finishing operation on the data.
		    goog.events.unlistenByKey(key);
		  });
		 </code>

		@param {!com.tripomatic.db.KeyRange=} opt_range The key range. If undefined iterates
		    over the whole object store.
		@param {!com.tripomatic.db.Cursor.Direction=} opt_direction The direction. If undefined
		    moves in a forward direction with duplicates.
		@return {!com.tripomatic.db.Cursor} The cursor.
		@throws {com.tripomatic.db.Error} If there was a problem opening the cursor.
	###
	openCursor: (opt_range, opt_direction) ->
		return com.tripomatic.db.Cursor.openCursor @store_, opt_range, opt_direction

	###*
		Deletes all objects from the store.

		@return {!goog.async.Deferred} The deferred clear request.
	###
	clear: () ->
		msg = 'clearing store ' + @getName()
		d = new goog.async.Deferred()
		try
			request = @store_.clear()
		catch err
			d.errback com.tripomatic.db.Error.fromException(err, msg)
			return d
		request.onsuccess = (ev) ->
			d.callback()
		request.onerror = (ev) ->
			d.errback com.tripomatic.db.Error.fromRequest(ev.target, msg)
		return d

	###*
		Creates an index in this object store. Can only be called inside the callback
		for the Deferred returned from com.tripomatic.IndexedDb#setVersion.

		@param {string} name Name of the index to create.
		@param {string} keyPath Attribute to index on.
		@param {!Object=} opt_parameters Optional parameters object. The only
		    available option is unique, which defaults to false. If unique is true,
		    the index will enforce that there is only ever one object in the object
		    store for each unique value it indexes on.
		@return {com.tripomatic.db.Index} The newly created, wrapped index.
		@throws {com.tripomatic.db.Error} In case of an error creating the index.
	###
	createIndex: (name, keyPath, opt_parameters) ->
		try
			return new com.tripomatic.db.Index this.store_.createIndex(name, keyPath, opt_parameters)
		catch ex
			msg = 'creating new index ' + name + ' with key path ' + keyPath
			throw com.tripomatic.db.Error.fromException ex, msg

	###*
		Gets an index.

		@param {string} name Name of the index to fetch.
		@return {com.tripomatic.db.Index} The requested wrapped index.
		@throws {com.tripomatic.db.Error} In case of an error getting the index.
	###
	getIndex: (name) ->
		try 
			return new com.tripomatic.db.Index @store_.index name
		catch ex
			msg = 'getting index ' + name
			throw com.tripomatic.db.Error.fromException ex, msg
		
	###*
		Deletes an index from the object store. Can only be called inside the
		callback for the Deferred returned from com.tripomatic.IndexedDb#setVersion.

		@param {string} name Name of the index to delete.
		@throws {com.tripomatic.db.Error} In case of an error deleting the index.
	###
	deleteIndex: (name) ->
		try
			@store_.deleteIndex name
		catch ex
			msg = 'deleting index ' + name
			throw com.tripomatic.db.Error.fromException ex, msg

	###*
		Gets number of records within a key range.

		@param {!com.tripomatic.db.KeyRange=} opt_range The key range. If undefined, this will
		     count all records in the object store.
		@return {!goog.async.Deferred} The deferred number of records.
	###
	count: (opt_range) ->
		d = new goog.async.Deferred
		try 
			if opt_range
				range = opt_range.range()
			else 
				range = null
			request = @store_.count range
		catch ex
			d.errback com.tripomatic.db.Error.fromException(ex, @getName())
		request.onsuccess = (ev) ->
			d.callback ev.target.result
		request.onerror = (ev) ->
			d.errback com.tripomatic.db.Error.fromRequest(ev.target, @getName())
		return d
