###*
@fileoverview Wrappers for the HTML5 IndexedDB. The wrappers export nearly
 the same interface as the standard API, but return goog.async.Deferred
 objects instead of request objects and use Closure events. The wrapper works
 and has been tested on Chrome version 22+. It may work on older Chrome
 versions, but they aren't explicitly supported.

 Example usage:
  <code>
   com.tripomatic.db.openDatabase('mydb', 1, function(ev, db, tx) {
    db.createObjectStore('mystore');
  }).addCallback(function(db) {
    var putTx = db.createTransaction(
        [],
        com.tripomatic.db.Transaction.TransactionMode.READ_WRITE);
    var store = putTx.objectStore('mystore');
    store.put('value', 'key');
    goog.listen(putTx, com.tripomatic.db.Transaction.EventTypes.COMPLETE, function() {
      var getTx = db.createTransaction([]);
      var request = getTx.objectStore('mystore').get('key');
      request.addCallback(function(result) {
        ...
      });
  });
  </code>
###

goog.provide 'com.tripomatic.db'

goog.require 'goog.async.Deferred'
goog.require 'com.tripomatic.db.Error'
goog.require 'com.tripomatic.db.IndexedDb'
goog.require 'com.tripomatic.db.Transaction'

###*
 The IndexedDB factory object.

 @type {IDBFactory}
 @private
###
com.tripomatic.db.indexedDb_ = goog.global.indexedDB || goog.global.mozIndexedDB ||
    goog.global.webkitIndexedDB || goog.global.moz_indexedDB

###*
 A callback that's called if a blocked event is received. When a database is
 supposed to be deleted or upgraded (i.e. versionchange), and there are open
 connections to this database, a block event will be fired to prevent the
 operations from going through until all such open connections are closed.
 This callback can be used to notify users that they should close other tabs
 that have open connections, or to close the connections manually. Databases
 can also listen for the {@link com.tripomatic.db.IndexedDb.EventType.VERSION_CHANGE}
 event to automatically close themselves when they're blocking such
 operations.

 This is passed a VersionChangeEvent that has the version of the database
 before it was deleted, and "null" as the new version.

 @typedef {function(!com.tripomatic.db.IndexedDb.VersionChangeEvent)}
###
com.tripomatic.db.BlockedCallback


###*
 A callback that's called when opening a database whose internal version is
 lower than the version passed to {@link com.tripomatic.db.openDatabase}.

 This callback is passed three arguments: a VersionChangeEvent with both the
 old version and the new version of the database; the database that's being
 opened, for which you can create and delete object stores; and the version
 change transaction, with which you can abort the version change.

 Note that the transaction is not active, which means that it can't be used to
 make changes to the database. However, since there is a transaction running,
 you can't create another one via {@link com.tripomatic.db.IndexedDb.createTransaction}.
 This means that it's not possible to manipulate the database other than
 creating or removing object stores in this callback.

 @typedef {function(!com.tripomatic.db.IndexedDb.VersionChangeEvent,
                    !com.tripomatic.db.IndexedDb,
                    !com.tripomatic.db.Transaction)}
###
com.tripomatic.db.UpgradeNeededCallback


###*
 Opens a database connection and wraps it.

 @param {string} name The name of the database to open.
 @param {number=} opt_version The expected version of the database. If this is
     larger than the actual version, opt_onUpgradeNeeded will be called
     (possibly after ; see {@link com.tripomatic.db.BlockedCallback}). If
     this is passed, opt_onUpgradeNeeded must be passed as well.
 @param {com.tripomatic.db.UpgradeNeededCallback=} opt_onUpgradeNeeded Called if
     opt_version is greater than the old version of the database. If
     opt_version is passed, this must be passed as well.
 @param {com.tripomatic.db.BlockedCallback=} opt_onBlocked Called if there are active
     connections to the database.
 @return {!goog.async.Deferred} The deferred database object.
###
com.tripomatic.db.openDatabase = (name, opt_version, opt_onUpgradeNeeded, opt_onBlocked) ->
	goog.asserts.assert(
		goog.isDef(opt_version) == goog.isDef(opt_onUpgradeNeeded),
		'opt_version must be passed to com.tripomatic.db.openDatabase if and only if ' +
			'opt_onUpgradeNeeded is also passed'
	)

	d = new goog.async.Deferred
	if opt_version
		openRequest = com.tripomatic.db.indexedDb_.open name, opt_version
	else
		openRequest = com.tripomatic.db.indexedDb_.open name 
	openRequest.onsuccess = (ev) ->
		db = new com.tripomatic.db.IndexedDb ev.target.result
		d.callback db

	openRequest.onerror = (ev) ->
		msg = 'opening database ' + name;
		d.errback com.tripomatic.db.Error.fromRequest ev.target, msg

	openRequest.onupgradeneeded = (ev) ->
		if !opt_onUpgradeNeeded 
			return
		db = new com.tripomatic.db.IndexedDb ev.target.result
		opt_onUpgradeNeeded(
			new com.tripomatic.db.IndexedDb.VersionChangeEvent(ev.oldVersion, ev.newVersion),
			db,
			new com.tripomatic.db.Transaction(ev.target.transaction, db)
		)

	openRequest.onblocked = (ev) ->
		if opt_onBlocked
			opt_onBlocked new com.tripomatic.db.IndexedDb.VersionChangeEvent(ev.oldVersion, ev.newVersion)

	return d

###*
 Deletes a database once all open connections have been closed.

 @param {string} name The name of the database to delete.
 @param {com.tripomatic.db.BlockedCallback=} opt_onBlocked Called if there are active
     connections to the database.
 @return {goog.async.Deferred} A deferred object that will fire once the
     database is deleted.
###
com.tripomatic.db.deleteDatabase = (name, opt_onBlocked) ->
	d = new goog.async.Deferred
	deleteRequest = com.tripomatic.db.indexedDb_.deleteDatabase name
	deleteRequest.onsuccess = (ev) ->
		d.callback()

	deleteRequest.onerror = (ev) ->
		msg = 'deleting database ' + name
		d.errback com.tripomatic.db.Error.fromRequest(ev.target, msg)

	deleteRequest.onblocked = (ev) ->
		if opt_onBlocked
			opt_onBlocked new com.tripomatic.db.IndexedDb.VersionChangeEvent(ev.oldVersion, ev.newVersion)
	return d

