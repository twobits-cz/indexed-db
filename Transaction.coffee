###*
	@fileoverview Wrapper for an IndexedDB transaction.
###


goog.provide 'com.tripomatic.db.Transaction'
goog.provide 'com.tripomatic.db.Transaction.TransactionMode'

goog.require 'goog.async.Deferred'
goog.require 'com.tripomatic.db.Error'
goog.require 'com.tripomatic.db.ObjectStore'
goog.require 'goog.events.EventHandler'
goog.require 'goog.events.EventTarget'

class com.tripomatic.db.Transaction extends goog.events.EventTarget

	###*
		Creates a new transaction. Transactions contain methods for accessing object
		stores and are created from the database object. Should not be created
		directly, open a database and call createTransaction on it.
		@see com.tripomatic.db.IndexedDb#createTransaction

		@param {!IDBTransaction} tx IndexedDB transaction to back this wrapper.
		@param {!com.tripomatic.db.IndexedDb} db The database that this transaction modifies.
		@constructor
		@extends {goog.events.EventTarget}
		@final
	###
	constructor: (tx, db) ->
		super()

		###*
			Underlying IndexedDB transaction object.
			
			@type {!IDBTransaction}
			@private
		###
		@tx_ = tx;

		###*
			The database that this transaction modifies.
			
			@type {!com.tripomatic.db.IndexedDb}
			@private
		###
		@db_ = db;

		###*
			Event handler for this transaction.
			
			@type {!goog.events.EventHandler}
			@private
		###
		@eventHandler_ = new goog.events.EventHandler @

		@eventHandler_.listen `/** @type {EventTarget} */ (this.tx_)`, 'complete', goog.bind(@dispatchEvent, @, com.tripomatic.db.Transaction.EventTypes.COMPLETE)
		@eventHandler_.listen `/** @type {EventTarget} */ (this.tx_)`, 'abort', goog.bind(@dispatchEvent, @, com.tripomatic.db.Transaction.EventTypes.ABORT)
		@eventHandler_.listen `/** @type {EventTarget} */ (this.tx_)`, 'error', @dispatchError_


	###*
		Dispatches an error event based on the given event, wrapping the error
		if necessary.
		
		@param {Event} ev The error event given to the underlying IDBTransaction.
		@private
	###
	dispatchError_: (ev) ->
		if ev.target instanceof com.tripomatic.db.Error
			@dispatchEvent
				type: com.tripomatic.db.Transaction.EventTypes.ERROR,
				target: ev.target
		else
			this.dispatchEvent
				type: com.tripomatic.db.Transaction.EventTypes.ERROR,
				target: com.tripomatic.db.Error.fromRequest `/** @type {!IDBRequest} */ (ev.target)`, 'in transaction'

	###
		Event types the Transaction can dispatch. COMPLETE events are dispatched
		when the transaction is committed. If a transaction is aborted it dispatches
		both an ABORT event and an ERROR event with the ABORT_ERR code. Error events
		are dispatched on any error.
		
		@enum {string}
	###
	@EventTypes = {
		COMPLETE: 'complete',
		ABORT: 'abort',
		ERROR: 'error'
	}

	###*
		@return {com.tripomatic.db.Transaction.TransactionMode} The transaction's mode.
	###
	getMode: () ->
		return `/** @type {com.tripomatic.db.Transaction.TransactionMode} */ (this.tx_.mode)`


	###*
		@return {!com.tripomatic.db.IndexedDb} The database that this transaction modifies.
	###
	getDatabase: () ->
		return @db_

	###*
		Opens an object store to do operations on in this transaction. The requested
		object store must be one that is in this transaction's scope.
		@see com.tripomatic.db.IndexedDb#createTransaction

		@param {string} name The name of the requested object store.
		@return {!com.tripomatic.db.ObjectStore} The wrapped object store.
		@throws {com.tripomatic.db.Error} In case of error getting the object store.
	###
	objectStore: (name) ->
		try
			return new com.tripomatic.db.ObjectStore @tx_.objectStore name
		catch ex
			throw com.tripomatic.db.Error.fromException ex, 'getting object store ' + name

	###*
		@return {!goog.async.Deferred} A deferred that will fire once the
		     transaction is complete. It fires the errback chain if an error occurs
		     in the transaction, or if it is aborted.
	###
	wait: () ->
		d = new goog.async.Deferred
		goog.events.listenOnce @, com.tripomatic.db.Transaction.EventTypes.COMPLETE, goog.bind(d.callback, d)
		goog.events.listenOnce @, com.tripomatic.db.Transaction.EventTypes.ABORT, () ->
			d.errback new com.tripomatic.db.Error(com.tripomatic.db.Error.ErrorCode.ABORT_ERR, 'waiting for transaction to complete')
		goog.events.listenOnce @, com.tripomatic.db.Transaction.EventTypes.ERROR, (e) ->
			d.errback e.target
		db = this.getDatabase()
		return d.addCallback(() ->
			return db
		)

	###*
		Aborts this transaction. No pending operations will be applied to the
		database. Dispatches an ABORT event.
	###
	abort: () ->
	  @tx_.abort()

	###*
		@override
	###
	disposeInternal: () ->
		super()
		@eventHandler_.dispose()

	###*
		The three possible transaction modes.
		@see http://www.w3.org/TR/IndexedDB/#idl-def-IDBTransaction

		@enum {string}
	###
	@TransactionMode = 
		READ_ONLY: 'readonly',
		READ_WRITE: 'readwrite',
		VERSION_CHANGE: 'versionchange'
