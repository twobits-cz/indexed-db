###*
	@fileoverview Wrapper for a IndexedDB cursor.
###
goog.provide 'com.tripomatic.db.Cursor'

goog.require 'com.tripomatic.db.Error'
goog.require 'goog.async.Deferred'
goog.require 'goog.debug'
goog.require 'goog.events.EventTarget'

###*
	Creates a new IDBCursor wrapper object. Should not be created directly,
	access cursor through object store.
	@see com.tripomatic.db.ObjectStore#openCursor

	@constructor
	@extends {goog.events.EventTarget}
	@final
###
class com.tripomatic.db.Cursor extends goog.events.EventTarget

	###*
		@param {!IDBDatabase} db Underlying IndexedDB database object.
		@constructor
	###
	constructor: (db) ->
		super()

	###*
		Underlying IndexedDB cursor object.

		@type {IDBCursor}
		@private
	###
	cursor_: null

	###*
		Advances the cursor to the next position along its direction. When new data
		is available, the NEW_DATA event will be fired. If the cursor has reached the
		end of the range it will fire the COMPLETE event. If opt_key is specified it
		will advance to the key it matches in its direction.

		This wraps the native #continue method on the underlying object.

		@param {IDBKeyType=} opt_key The optional key to advance to.
	###
	next = (opt_key) ->
		if opt_key
			this.cursor_['continue'](opt_key)
		else
			this.cursor_['continue']()

	###*
		Updates the value at the current position of the cursor in the object store.
		If the cursor points to a value that has just been deleted, a new value is
		created.

		@param {*} value The value to be stored.
		@return {!goog.async.Deferred} The resulting deferred request.
	###
	update: (value) ->
		msg = 'updating via cursor with value '
		d = new goog.async.Deferred
		try
			request = @cursor_.update value
		catch err
			msg += goog.debug.deepExpose value
			d.errback goog.db.Error.fromException(err, msg)
			return d
		
		request.onsuccess = (ev) ->
			d.callback()
		request.onerror = (ev) ->
			msg += goog.debug.deepExpose value
			d.errback goog.db.Error.fromRequest(ev.target, msg)
		return d

	###*
		Deletes the value at the cursor's position, without changing the cursor's
		position. Once the value is deleted, the cursor's value is set to null.

		@return {!goog.async.Deferred} The resulting deferred request.
	###
	remove: () ->
		msg = 'deleting via cursor'
		d = new goog.async.Deferred
		try
			request = this.cursor_['delete']()
		catch err
			d.errback com.tripomatic.db.Error.fromException(err, msg)
			return d
		request.onsuccess = (ev) ->
			d.callback()
		request.onerror = (ev) ->
			d.errback com.tripomatic.db.Error.fromRequest(ev.target, msg)
		return d

	###*
		@return {*} The value for the value at the cursor's position. Undefined
		    if no current value, or null if value has just been deleted.
	###
	getValue: () ->
		return @cursor_['value'];

	###*
		@return {IDBKeyType} The key for the value at the cursor's position. If
		    the cursor is outside its range, this is undefined.
	###
	getKey: () ->
		return @cursor_.key

	###*
		Opens a value cursor from IDBObjectStore or IDBIndex over the specified key
		range. Returns a cursor object which is able to iterate over the given range.
		@param {!(IDBObjectStore|IDBIndex)} source Data source to open cursor.
		@param {!com.tripomatic.db.KeyRange=} opt_range The key range. If undefined iterates
		    over the whole data source.
		@param {!com.tripomatic.db.Cursor.Direction=} opt_direction The direction. If undefined
		    moves in a forward direction with duplicates.
		@return {!com.tripomatic.db.Cursor} The cursor.
		@throws {com.tripomatic.db.Error} If there was a problem opening the cursor.
	###
	@openCursor = (source, opt_range, opt_direction) ->
		cursor = new com.tripomatic.db.Cursor
		try
			if opt_range
				range = opt_range.range()
			else
				range = null
			if opt_direction
				request = source.openCursor range, opt_direction
			else
				request = source.openCursor range
		catch ex
			cursor.dispose()
			throw com.tripomatic.db.Error.fromException ex, source.name
		request.onsuccess = (e) ->
			cursor.cursor_ = e.target.result || null
			if cursor.cursor_
				cursor.dispatchEvent com.tripomatic.db.Cursor.EventType.NEW_DATA
			else
				cursor.dispatchEvent com.tripomatic.db.Cursor.EventType.COMPLETE
		request.onerror = (e) ->
			cursor.dispatchEvent com.tripomatic.db.Cursor.EventType.ERROR
	
		return cursor

	###*
		Possible cursor directions.
		@see http://www.w3.org/TR/IndexedDB/#idl-def-IDBCursor

		@enum {string}
	###
	@Direction = {
		NEXT: 'next',
		NEXT_NO_DUPLICATE: 'nextunique',
		PREV: 'prev',
		PREV_NO_DUPLICATE: 'prevunique'
	}

	###*
		Event types that the cursor can dispatch. COMPLETE events are dispatched when
		a cursor is depleted of values, a NEW_DATA event if there is new data
		available, and ERROR if an error occurred.

		@enum {string}
	###
	@EventType = {
		COMPLETE: 'c',
		ERROR: 'e',
		NEW_DATA: 'n'
	}
