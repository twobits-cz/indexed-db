goog.provide 'com.tripomatic.db.Index'

goog.require 'goog.async.Deferred'
goog.require 'com.tripomatic.db.Cursor'
goog.require 'com.tripomatic.db.Error'
goog.require 'goog.debug'

###*
	Creates an IDBIndex wrapper object. Indexes are associated with object
	stores and provide methods for looking up objects based on their non-key
	properties. Should not be created directly, access through the object store
	it belongs to.
	@see goog.db.ObjectStore#getIndex
	@param {!IDBIndex} index Underlying IDBIndex object.
	@constructor
	@final
###
class com.tripomatic.db.Index 

	constructor: (index) ->
		###*
	  		Underlying IndexedDB index object.
	  		@type {!IDBIndex}
	  		@private
  		###
		@index_ = index

	###*
		@return {string} Name of the index.
	###
	getName: () ->
		return @index_.name


	###*
		@return {string} Key path of the index.
	###
	getKeyPath: () ->
		@index_.keyPath


	###*
		@return {boolean} True if the index enforces that there is only one object
		    for each unique value it indexes on.
	###
	isUnique: () ->
		@index_.unique


	###*
		Helper function for get and getKey.
		@param {string} fn Function name to call on the index to get the request.
		@param {string} msg Message to give to the error.
		@param {IDBKeyType} key The key to look up in the index.
		@return {!goog.async.Deferred} The resulting deferred object.
		@private
	###
	get_: (fn, msg, key) ->
		d = new goog.async.Deferred()
		request = null
		try
			request = @index_[fn](key)
		catch err
			msg += ' with key ' + goog.debug.deepExpose key
			d.errback(com.tripomatic.db.Error.fromException(err, msg))
			return d
		request.onsuccess = (ev) ->
			d.callback(ev.target.result)
		request.onerror =  (ev) ->
			msg += ' with key ' + goog.debug.deepExpose key
			d.errback com.tripomatic.db.Error.fromRequest(ev.target, msg) 
		return d

	###*
		Fetches a single object from the object store. Even if there are multiple
		objects that match the given key, this method will get only one of them.
		@param {IDBKeyType} key Key to look up in the index.
		@return {!goog.async.Deferred} The deferred object for the given record.
	###
	get: (key) ->
	  return @get_ 'get', 'getting from index ' + @getName(), key 

	###*
		Looks up a single object from the object store and gives back the key that
		it's listed under in the object store. Even if there are multiple records
		that match the given key, this method returns the first.
		@param {IDBKeyType} key Key to look up in the index.
		@return {!goog.async.Deferred} The deferred key for the record that matches
		    the key.
	###
	getKey: (key) ->
	  return @get_ 'getKey', 'getting key from index ' + @getName(), key

	###*
		Helper function for getAll and getAllKeys.
		@param {string} fn Function name to call on the index to get the request.
		@param {string} msg Message to give to the error.
		@param {IDBKeyType=} opt_key Key to look up in the index.
		@return {!goog.async.Deferred} The resulting deferred array of objects.
		@private
	###
	getAll_: (fn, msg, opt_key) ->
		#This is the most common use of IDBKeyRange. If more specific uses of
		#cursors are needed then a full wrapper should be created.
		IDBKeyRange = goog.global.IDBKeyRange || goog.global.webkitIDBKeyRange
		d = new goog.async.Deferred()
		request = null
		try
			if opt_key
				request = @index_[fn](IDBKeyRange.only(opt_key))
			else
				request = @index_[fn]()
		catch err
			if opt_key
				msg += ' for key ' + goog.debug.deepExpose opt_key 
				d.errback com.tripomatic.db.Error.fromException(err, msg)
			return d
		result = []
		request.onsuccess = (ev) ->
			cursor = ev.target.result
			if cursor
				result.push(cursor.value)
				cursor['continue']()
			else
				d.callback(result)
		request.onerror = (ev) ->
			if opt_key
				msg += ' for key ' + goog.debug.deepExpose(opt_key)
			d.errback com.tripomatic.db.Error.fromRequest(ev.target, msg)
		return d

	###*
		Gets all indexed objects. If the key is provided, gets all indexed objects
		that match the key instead.
		@param {IDBKeyType=} opt_key Key to look up in the index.
		@return {!goog.async.Deferred} A deferred array of objects that match the
		    key.
	###
	getAll: (opt_key) ->
		return @getAll_(
			'openCursor',
			'getting all from index ' + @getName(),
			opt_key
	    )

	###*
		Gets the keys to look up all the indexed objects. If the key is provided,
		gets all records for objects that match the key instead.
		@param {IDBKeyType=} opt_key Key to look up in the index.
		@return {!goog.async.Deferred} A deferred array of keys for objects that
		    match the key.
	###
	getAllKeys: (opt_key) ->
		return @getAll_(
			'openKeyCursor',
			'getting all keys from index ' + @getName(),
			opt_key
		)


	###*
		Opens a cursor over the specified key range. Returns a cursor object which is
		able to iterate over the given range.
		Example usage:
		<code>
		 var cursor = index.openCursor(com.tripomatic.db.KeyRange.bound('a', 'c'))
		 var key = goog.events.listen(
		     cursor, com.tripomatic.db.Cursor.EventType.NEW_DATA,
		     function() {
		       // Do something with data.
		       cursor.next()
		     })
		 goog.events.listenOnce(
		     cursor, com.tripomatic.db.Cursor.EventType.COMPLETE,
		     function() {
		       // Clean up listener, and perform a finishing operation on the data.
		       goog.events.unlistenByKey(key)
		     })
		</code>
		@param {!com.tripomatic.db.KeyRange=} opt_range The key range. If undefined iterates
		    over the whole object store.
		@param {!com.tripomatic.db.Cursor.Direction=} opt_direction The direction. If undefined
		    moves in a forward direction with duplicates.
		@return {!com.tripomatic.db.Cursor} The cursor.
		@throws {com.tripomatic.db.Error} If there was a problem opening the cursor.
	###
	openCursor: (opt_range, opt_direction) ->
		return com.tripomatic.db.Cursor.openCursor(@index_, opt_range, opt_direction)
