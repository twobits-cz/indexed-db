goog.provide tripomatic.db.KeyRange

###*
	Creates a new IDBKeyRange wrapper object. Should not be created directly,
	instead use one of the static factory methods. For example:
	@see tripomatic.db.KeyRange.bound
	@see tripomatic.db.KeyRange.lowerBound
	@param {!IDBKeyRange} range Underlying IDBKeyRange object.
	@constructor
	@final
 ###
class tripomatic.db.KeyRange 


	constructor: (@range_)->

	###*
		The IDBKeyRange.
		@type {!Object}
		@private
	###
	@IDB_KEY_RANGE_ = goog.global.IDBKeyRange || goog.global.webkitIDBKeyRange


	###*
		Creates a new key range for a single value.
		@param {IDBKeyType} key The single value in the range.
		@return {!tripomatic.db.KeyRange} The key range.
	###
	@only: (key) ->
	  return new tripomatic.db.KeyRange(tripomatic.db.KeyRange.IDB_KEY_RANGE_.only(key))


	###*
		Creates a key range with upper and lower bounds.
		@param {IDBKeyType} lower The value of the lower bound.
		@param {IDBKeyType} upper The value of the upper bound.
		@param {boolean=} opt_lowerOpen If true, the range excludes the lower bound
		    value.
		@param {boolean=} opt_upperOpen If true, the range excludes the upper bound
		    value.
		@return {!tripomatic.db.KeyRange} The key range.
	###
	@bound: (lower, upper, opt_lowerOpen, opt_upperOpen) ->
	  return new tripomatic.db.KeyRange(tripomatic.db.KeyRange.IDB_KEY_RANGE_.bound(
	      lower, upper, opt_lowerOpen, opt_upperOpen))


	###*
		Creates a key range with a lower bound only, finishes at the last record.
		@param {IDBKeyType} lower The value of the lower bound.
		@param {boolean=} opt_lowerOpen If true, the range excludes the lower bound
		    value.
		@return {!tripomatic.db.KeyRange} The key range.
	###
	@lowerBound: (lower, opt_lowerOpen) ->
	  return new tripomatic.db.KeyRange(tripomatic.db.KeyRange.IDB_KEY_RANGE_.lowerBound(
	      lower, opt_lowerOpen))


	###*
		Creates a key range with a upper bound only, starts at the first record.
		@param {IDBKeyType} upper The value of the upper bound.
		@param {boolean=} opt_upperOpen If true, the range excludes the upper bound
		    value.
		@return {!tripomatic.db.KeyRange} The key range.
	###
	@upperBound: (upper, opt_upperOpen) ->
	  return new tripomatic.db.KeyRange(tripomatic.db.KeyRange.IDB_KEY_RANGE_.upperBound(
	      upper, opt_upperOpen))


	###*
		Returns underlying key range object. This is used in ObjectStore's openCursor
		and count methods.
		@return {!IDBKeyRange}
	###
	range: () ->
	  return @range_
