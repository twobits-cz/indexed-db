###*
	@fileoverview Wrapper for an IndexedDB database.
###

goog.provide 'com.tripomatic.db.IndexedDb'

goog.require 'com.tripomatic.db.Error'
goog.require 'com.tripomatic.db.Error.VersionChangeBlockedError'
goog.require 'com.tripomatic.db.ObjectStore'
goog.require 'com.tripomatic.db.Transaction'
goog.require 'com.tripomatic.db.Transaction.TransactionMode'
goog.require 'goog.async.Deferred'
goog.require 'goog.events.Event'
goog.require 'goog.events.EventHandler'
goog.require 'goog.events.EventTarget'



###*
	Creates an IDBDatabase wrapper object. The database object has methods for
	setting the version to change the structure of the database and for creating
	transactions to get or modify the stored records. Should not be created
	directly, call {@link com.tripomatic.db.openDatabase} to set up the connections
###
class com.tripomatic.db.IndexedDb extends goog.events.EventTarget

	###*
		@param {!IDBDatabase} db Underlying IndexedDB database object.
		@constructor
		@extends {goog.events.EventTarget}
	###
	constructor: (db) ->
		super()

		###*
			Underlying IndexedDB database object.
			
			@type {!IDBDatabase}
			@private
		###
		@db_ = db;

		###*
			Internal event handler that listens to IDBDatabase events.
			@type {!goog.events.EventHandler}
			@private
		###
		@eventHandler_ = new goog.events.EventHandler @

		@eventHandler_.listen @db_, com.tripomatic.db.IndexedDb.EventType.ABORT, goog.bind(@dispatchEvent, @, com.tripomatic.db.IndexedDb.EventType.ABORT)
		@eventHandler_.listen @db_, com.tripomatic.db.IndexedDb.EventType.ERROR, @dispatchError_
		@eventHandler_.listen @db_, com.tripomatic.db.IndexedDb.EventType.VERSION_CHANGE, @dispatchVersionChange_

	###*
		True iff the database connection is open.

		@type {boolean}
		@private
	###
	open_: true


	###*
		Dispatches a wrapped error event based on the given event.

		@param {Event} ev The error event given to the underlying IDBDatabase.
		@suppress {deprecated}
		@private
	###
	dispatchError_: (ev) ->
		@dispatchEvent(
			type: com.tripomatic.db.IndexedDb.EventType.ERROR,
			errorCode: `/** @type {IDBRequest} */ (ev.target).errorCode`
		)

	###*
		Dispatches a wrapped version change event based on the given event.

		@param {Event} ev The version change event given to the underlying
		    IDBDatabase.
		@private
	###
	dispatchVersionChange_: (ev) ->
		@dispatchEvent new com.tripomatic.db.IndexedDb.VersionChangeEvent(ev.oldVersion, ev.newVersion)


	###*
		Closes the database connection. Metadata queries can still be made after this
		method is called, but otherwise this wrapper should not be used further.
	###
	close: () ->
		if @open_
			@db_.close()
			@open_ = false;
		
	###*
	@return {boolean} Whether a connection is open and the database can be used.
	###
	isOpen: () ->
		return @open_

	###*
		@return {string} The name of this database.
	###
	getName: () ->
		return @db_.name

	###*
		@return {string} The current database version.
	###
	getVersion: () ->
		return @db_.version;

	###*
		@return {DOMStringList} List of object stores in this database.
	###
	getObjectStoreNames: () ->
		return @db_.objectStoreNames

	###*
		Creates an object store in this database. Can only be called inside a
		{@link com.tripomatic.db.UpgradeNeededCallback} or the callback for the Deferred
		returned from #setVersion.

		@param {string} name Name for the new object store.
		@param {Object=} opt_params Options object. The available options are:
		    keyPath, which is a string and determines what object attribute
		    to use as the key when storing objects in this object store; and
		    autoIncrement, which is a boolean, which defaults to false and determines
		    whether the object store should automatically generate keys for stored
		    objects. If keyPath is not provided and autoIncrement is false, then all
		    insert operations must provide a key as a parameter.
		@return {com.tripomatic.db.ObjectStore} The newly created object store.
		@throws {com.tripomatic.db.Error} If there's a problem creating the object store.
	###
	createObjectStore: (name, opt_params) ->
		try
			return new com.tripomatic.db.ObjectStore @db_.createObjectStore(name, opt_params)
		catch ex
			throw com.tripomatic.db.Error.fromException ex, 'creating object store ' + name

	###*
		Deletes an object store. Can only be called inside a
		{@link com.tripomatic.db.UpgradeNeededCallback} or the callback for the Deferred
		returned from #setVersion.

		@param {string} name Name of the object store to delete.
		@throws {com.tripomatic.db.Error} If there's a problem deleting the object store.
	###
	deleteObjectStore: (name) ->
		try 
			@db_.deleteObjectStore name
		catch ex
			throw com.tripomatic.db.Error.fromException ex, 'deleting object store ' + name

	###*
		Updates the version of the database and returns a Deferred transaction.
		The database's structure can be changed inside this Deferred's callback, but
		nowhere else. This means adding or deleting object stores, and adding or
		deleting indexes. The version change will not succeed unless there are no
		other connections active for this database anywhere. A new database
		connection should be opened after the version change is finished to pick
		up changes.

		This is deprecated, and only supported on Chrome prior to version 25. New
		applications should use the version parameter to {@link com.tripomatic.db.openDatabase}
		instead.
		@param {string} version The new version of the database.
		@return {!goog.async.Deferred} The deferred transaction for changing the
		    version.
	###
	setVersion: (version) ->
		d = new goog.async.Deferred();
		request = @db_.setVersion version
		request.onsuccess = (ev) =>
			#the transaction is in the result field (the transaction field is null
			#for version change requests)
			d.callback new com.tripomatic.db.Transaction(ev.target.result, @) 
		request.onerror = (ev) ->
			#If a version change is blocked, onerror and onblocked may both fire.
			#Check d.hasFired() to avoid an AlreadyCalledError.
			if !d.hasFired()
				d.errback com.tripomatic.db.Error.fromRequest(ev.target, 'setting version')
		request.onblocked = (ev) ->
			#If a version change is blocked, onerror and onblocked may both fire.
			#Check d.hasFired() to avoid an AlreadyCalledError.
			if !d.hasFired()
				d.errback new com.tripomatic.db.Error.VersionChangeBlockedError()
		return d

	###*
		Creates a new transaction.

		@param {!Array.<string>} storeNames A list of strings that contains the
		    transaction's scope, the object stores that this transaction can operate
		    on.
		@param {com.tripomatic.db.Transaction.TransactionMode=} opt_mode The mode of the
		    transaction. If not present, the default is READ_ONLY. For VERSION_CHANGE
		    transactions call {@link com.tripomatic.db.IndexedDB#setVersion} instead.
		@return {!com.tripomatic.db.Transaction} The wrapper for the newly created transaction.
		@throws {com.tripomatic.db.Error} If there's a problem creating the transaction.
	###
	createTransaction: (storeNames, opt_mode) ->
		try
			# IndexedDB on Chrome 22+ requires that opt_mode not be passed rather than
			# be explicitly passed as undefined.
			if opt_mode
				transaction = @db_.transaction storeNames, opt_mode
			else
				transaction = @db_.transaction storeNames
			return new com.tripomatic.db.Transaction transaction, @
		catch ex
			throw com.tripomatic.db.Error.fromException ex, 'creating transaction' 
	
	###* 
		@override 
	###
	disposeInternal: () ->
		super()
		@eventHandler_.dispose()


	###*
		Event types fired by a database.
		
		@enum {string} The event types for the web socket.
	###
	@EventType = {

		###*
			Fired when a transaction is aborted and the event bubbles to its database.
		###
		ABORT: 'abort',

		###*
			Fired when a transaction has an error.
		###
		ERROR: 'error',

		###*
			Fired when someone (possibly in another window) is attempting to modify the
			structure of the database. Since a change can only be made when there are
			no active database connections, this usually means that the database should
			be closed so that the other client can make its changes.
		###
		VERSION_CHANGE: 'versionchange'
	}


class com.tripomatic.db.IndexedDb.VersionChangeEvent extends goog.events.Event

	###*
		@param {number} oldVersion The previous version of the database.
		@param {number} newVersion The version the database is being or has been updated to.
		@extends {goog.events.Event}
		@constructor
	###
	constructor: (@oldVersion, @newVersion) ->
		super com.tripomatic.db.IndexedDb.EventType.VERSION_CHANGE

