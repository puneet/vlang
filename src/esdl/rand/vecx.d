module esdl.rand.vecx;

import esdl.data.bvec;
import esdl.data.bstr;
import std.traits: isIntegral, isBoolean, isArray, isStaticArray, isDynamicArray;

import esdl.rand.obdd;
import esdl.rand.misc;
import esdl.rand.intr;
import esdl.rand.base: CstVecPrim, CstVecExpr, CstIteratorBase,
  CstStage, CstDomain, CstBddExpr, CstEquation, _esdl__Solver; // CstValAllocator,
import esdl.rand.expr: CstVecLen, CstVecDomain, _esdl__cstVal,
  CstVecTerm;

import esdl.rand.intr: IntRangeSet;

// Consolidated Proxy Class
// template CstVecBase(T, int I, int N=0) {
//   alias CstVecBase = CstVecBase!(typeof(T.tupleof[I]),
// 				     getRandAttr!(T, I), N);
// }

abstract class CstVecBase(V, alias R, int N)
  if(_esdl__ArrOrder!(V, N) == 0): CstVecDomain!(ElementTypeN!(V, N), R), CstVecPrim
{
  enum HAS_RAND_ATTRIB = (! __traits(isSame, R, _esdl__norand));

  alias E = ElementTypeN!(V, N);

  string _name;

  Unconst!E _refreshedVal;

  static if (HAS_RAND_ATTRIB) {
    CstVecPrim[] _preReqs;
  }

  this(string name) {
    _name = name;
  }

  static if(HAS_RAND_ATTRIB && is(E == enum)) {
    BDD _primBdd;
    override BDD getPrimBdd(Buddy buddy) {
      import std.traits;
      if(_primBdd.isZero()) {
	foreach(e; EnumMembers!E) {
	  _primBdd = _primBdd | this.bddvec(buddy).equ(buddy.buildVec(e));
	}
      }
      return _primBdd;
    }
    void resetPrimeBdd() {
      _primBdd.reset();
    }
  }
  else {
    override BDD getPrimBdd(Buddy buddy) {
      return buddy.one();
    }
    void resetPrimeBdd() { }
  }

  ~this() {
    resetPrimeBdd();
  }

  override string name() {
    return _name;
  }

  void _esdl__reset() {
    static if (HAS_RAND_ATTRIB) {
      _stage = null;
      _resolveLap = 0;
    }
  }

  bool isVarArr() {
    return false;
  }

  abstract long value();
  
  bool getVal(ref long val) {
    static if (HAS_RAND_ATTRIB) {
      if(! this.isRand || stage().solved()) {
	val = value();
	return true;
      }
      else {
	return false;
      }
    }
    else {
      val = value();
      return true;
    }
  }

  long evaluate() {
    static if (HAS_RAND_ATTRIB) {
      if(! this.isRand || stage().solved()) {
	return value();
      }
      else {
	import std.conv;
	assert(false, "Rand variable " ~ _name ~
	       " evaluation in wrong stage: " ~ stage()._id.to!string);
      }
    }
    else {
      return value();
    }
  }

  override uint bitcount() {
    static if(isBoolean!E)         return 1;
    else static if(isIntegral!E)   return E.sizeof * 8;
    else static if(isBitVector!E)  return E.SIZE;
    else static assert(false, "bitcount can not operate on: " ~ E.stringof);
  }

  override bool signed() {
    static if(isVecSigned!E) {
      return true;
    }
    else  {
      return false;
    }
  }

  S to(S)()
    if (is(S == string)) {
      import std.conv;
      static if (HAS_RAND_ATTRIB) {
	if (isRand) {
	  return "RAND#" ~ _name ~ ":" ~ value().to!string();
	}
	else {
	  return "VAL#" ~ _name ~ ":" ~ value().to!string();
	}
      }
      else {
	return "VAR#" ~ _name ~ ":" ~ value().to!string();
      }
    }

  override string toString() {
    return this.to!string();
  }

  void solveBefore(CstVecPrim other) {
    static if (HAS_RAND_ATTRIB) {
      other.addPreRequisite(this);
    }
    else {
      assert(false);
    }
  }

  void addPreRequisite(CstVecPrim domain) {
    static if (HAS_RAND_ATTRIB) {
      _preReqs ~= domain;
    }
    else {
      assert(false);
    }
  }

  abstract E* getRef();
  
  override bool isRand() {
    static if (HAS_RAND_ATTRIB) {
      return true;
    }
    else {
      return false;
    }
  }
}

// T represents the type of the declared array/non-array member
// N represents the level of the array-elements we have to traverse
// for the elements this CstVec represents
template CstVec(T, int I, int N=0)
  if(_esdl__ArrOrder!(T, I, N) == 0) {
  alias CstVec = CstVec!(typeof(T.tupleof[I]),
			 getRandAttr!(T, I), N);
}

class CstVec(V, alias R, int N) if(N == 0 && _esdl__ArrOrder!(V, N) == 0):
  CstVecBase!(V, R, N)
    {
      import std.traits;
      import std.range;
      import esdl.data.bvec;

      alias E = ElementTypeN!(V, N);
      alias RV = typeof(this);

      V* _var;
      _esdl__Solver _parent;
    
      this(string name, ref V var, _esdl__Solver parent) {
	// import std.stdio;
	// writeln("New vec ", name);
	super(name);
	_var = &var;
	_parent = parent;
	static if (HAS_RAND_ATTRIB) {
	  getSolverRoot().addDomain(this);
	}
      }

      bool isConcrete() {
	return true;		// N == 0
      }

      void _esdl__setValRef(ref V var) {
	_var = &var;
      }
      
      _esdl__Solver getSolverRoot() {
	assert(_parent !is null);
	return _parent.getSolverRoot();
      }
	
      CstVecPrim[] preReqs() {
	static if (HAS_RAND_ATTRIB) {
	  return _preReqs;
	}
	else {
	  return [];
	}
      }

      CstIteratorBase[] iterVars() {
	return [];
      }

      CstIteratorBase getIterator() {
	return null;
      }

      CstDomain[] unresolvedIndxs() {
	return [];
      }

      bool hasUnresolvedIndx() {
	return false;
      }
      
      CstDomain[] getRndDomains(bool resolved) {
	static if (HAS_RAND_ATTRIB) {
	  if(isRand) return [this];
	  else return [];
	}
	else {
	  return [];
	}
      }

      CstDomain[] getDomainLens(bool resolved) {
	assert(false);
      }

      // RV
      CstVecExpr unroll(CstIteratorBase iter, uint n) {
	// iterVars is always empty
	return this;
      }

      override void _esdl__doRandomize(_esdl__RandGen randGen) {
	static if (HAS_RAND_ATTRIB) {
	  if(stage is null) {
	    randGen.gen(*_var);
	  }
	}
	else {
	  assert(false);
	}
      }

      override void _esdl__doRandomize(_esdl__RandGen randGen, CstStage s) {
	static if (HAS_RAND_ATTRIB) {
	  assert (stage is s);
	  randGen.gen(*_var);
	}
	else {
	  assert(false);
	}
      }

      override E* getRef() {
	return _var;
      }

      override long value() {
	return cast(long) (*_var);
      }

      bool refresh(CstStage s, Buddy buddy) {
	static if (HAS_RAND_ATTRIB) {
	  assert (stage(), "Stage not set for " ~ this.name());
	  if (this.isRand && s is stage()) {
	    return false;
	  }
	  else if ((! this.isRand) ||
		   this.isRand && stage().solved()) { // work with the value
	    return refreshVal(buddy);
	  }
	  else {
	    assert(false, "Constraint evaluation in wrong stage");
	  }
	}
	else {
	  return refreshVal(buddy);
	}
      }
  
      private bool refreshVal(Buddy buddy) {
	auto val = *(getRef());
	if (_valvec.isNull ||
	    val != _refreshedVal) {
	  _valvec.buildVec(buddy, val);
	  _refreshedVal = val;
	  return true;
	}
	else {
	  return false;
	}
      }
  
      BddVec getBDD(CstStage s, Buddy buddy) {
	static if (HAS_RAND_ATTRIB) {
	  assert(stage(), "Stage not set for " ~ this.name());
	  if(this.isRand && s is stage()) {
	    return bddvec(buddy);
	    // return _domvec;
	  }
	  else if((! this.isRand) ||
		  this.isRand && stage().solved()) { // work with the value
	    return _valvec;
	  }
	  else {
	    assert(false, "Constraint evaluation in wrong stage");
	  }
	}
	else {
	  return _valvec;
	}
      }

      override void collate(ulong v, int word = 0) {
	static if (HAS_RAND_ATTRIB) {
	  static if(isIntegral!V || isBoolean!V) {
	    if(word == 0) {
	      *_var = cast(V) v; // = cast(V) toBitVec(v      }
	    }
	    else {
	      static if(size_t.sizeof == 4 && (is(V == long) || is(V == ulong))) {
		assert(word == 1);	// 32 bit machine with long integral
		V val = v;
		val = val << (8 * size_t.sizeof);
		*_var += val;
	      }
	      else {
		assert(false, "word has to be 0 for integrals");
	      }
	    }
	  }
	  else {
	    _var._setNthWord(v, word); // = cast(V) toBitVec(v);
	  }
	}
	else {
	  assert(false);
	}
      }

      bool isConst() {
	return false;
      }

      bool isOrderingExpr() {
	return false;		// only CstVecOrderingExpr return true
      }

      void setBddContext(CstEquation eqn,
				  ref CstDomain[] vars,
				  ref CstDomain[] vals,
				  ref CstIteratorBase iter,
				  ref CstDomain[] deps) {
	static if (is (R: _esdl__norand)) {
	  vals ~= this;
	}
	else {
	  bool listed;
	  foreach (var; vars) {
	    if (var is this) {
	      listed = true;
	      break;
	    }
	  }
	  if (listed is false) {
	    vars ~= this;
	  }
	}
      }

      bool getIntMods(ref IntRangeModSet modSet) {
	return true;
      }
    }

class CstVec(V, alias R, int N=0) if(N != 0 && _esdl__ArrOrder!(V, N) == 0):
  CstVecBase!(V, R, N)
    {
      import std.traits;
      import std.range;
      import esdl.data.bvec;

      alias RV = typeof(this);
      alias P = CstVecArr!(V, R, N-1);
      P _parent;

      CstVecExpr _indexExpr = null;
      int _pindex = 0;

      this(string name, P parent, CstVecExpr indexExpr) {
	// import std.stdio;
	// writeln("New ", name);
	assert(parent !is null);
	super(name);
	_parent = parent;
	_indexExpr = indexExpr;
	// only concrete elements need be added
	// getSolverRoot().addDomain(this);
      }

      this(string name, P parent, uint index) {
	// import std.stdio;
	// writeln("New ", name);
	assert(parent !is null);
	super(name);
	_parent = parent;
	// _indexExpr = _esdl__cstVal(index);
	_pindex = index;
	getSolverRoot().addDomain(this);
      }

      bool isConcrete() {
	return (_indexExpr is null);
      }

      _esdl__Solver getSolverRoot() {
	assert(_parent !is null);
	return _parent.getSolverRoot();
      }
	
      CstVecPrim[] preReqs() {
	if(_indexExpr) {
	  static if (HAS_RAND_ATTRIB) {
	    return _preReqs ~ _parent.arrLen() ~
	      _parent.preReqs() ~ _indexExpr.preReqs();
	  }
	  else {
	    return _parent.preReqs() ~ _indexExpr.preReqs();
	  }
	}
	else {
	  static if (HAS_RAND_ATTRIB) {
	    return _preReqs ~ _parent.arrLen() ~ _parent.preReqs();
	  }
	  else {
	    return _parent.preReqs();
	  }
	}
      }

      CstIteratorBase[] iterVars() {
	if (_indexExpr) {
	  return _parent.iterVars() ~ _indexExpr.iterVars();
	}
	else {
	  return _parent.iterVars();
	}
      }

      CstIteratorBase getIterator() {
	CstIteratorBase piter = _parent.getIterator();
	if (_indexExpr) {
	  if (piter !is null) return piter;
	  else return _indexExpr.getIterator();
	}
	else {
	  return piter;
	}
      }

      CstDomain[] unresolvedIndxs() {
	return _parent.unresolvedIndxs();
      }

      bool hasUnresolvedIndx() {
	return _parent.hasUnresolvedIndx(); // no _relatedIndxs for this instance
      }
      
      CstDomain[] getDomainLens(bool resolved) {
	assert(false);
      }

      // What is required here
      // we could be dealing with an _pindex or an _indexExpr. Further
      // the indexExpr could be either a solvable constraint expression
      // or an array length iterator that iterates over the length of
      // the given array. To add to the complexity here, we could have a
      // case where the given element has a parent that too a
      // non-elementary one (involving non-integer indexes). In such
      // cases we need to list all the elements of the array that could
      // finally represent the given element that we are currently
      // dealing with.
      CstDomain[] getRndDomains(bool resolved) {
	CstDomain[] domains;
	static if (HAS_RAND_ATTRIB) {
	  if (_indexExpr) {
	    if (_indexExpr.isConst() || resolved) {
	      // domains = cast (CstDomain[]) _parent.getDomainElems(_indexExpr.evaluate());
	      foreach(pp; _parent.getDomainElems(cast(size_t) _indexExpr.evaluate())) {
		domains ~= pp;
	      }
	    }
	    else {
	      // FIXME -- if the expression has been solved
	      // return _parent.getRndDomainsAtIndx(_indexExpr.evaluate()) ;
	      domains = _indexExpr.getRndDomains(resolved);
	      foreach(pp; _parent.getDomainElems(-1)) {
		domains ~= pp;
	      }
	      // domains ~= _parent.getDomainElems(-1);
	    }
	  }
	  else {
	    foreach(pp; _parent.getDomainElems(_pindex)) {
	      domains ~= pp;
	    }
	    // domains =  cast (CstDomain[]) _parent.getDomainElems(_pindex);
	  }
	  return domains;
	}
	else {
	  if(_indexExpr) {
	    // FIXME -- if the expression has been solved
	    // return _parent.getDomainElems(_indexExpr.evaluate()) ;
	    domains = _indexExpr.getRndDomains(resolved) ~ _parent.getRndDomains(resolved);
	  }
	  else {
	    // foreach(pp; _parent.getDomainElems(_pindex)) {
	    //   domains ~= pp;
	    // }
	    domains = _parent.getRndDomains(resolved);
	  }
	  return domains;
	}
      }

      // RV
      CstVecExpr unroll(CstIteratorBase iter, uint n) {
	bool found = false;
	foreach(var; iterVars()) {
	  if(iter is var) {
	    found = true;
	    break;
	  }
	}
	if(! found) {		// iter is unrelated
	  return this;
	}
	else if(_indexExpr) {
	  return _parent.unroll(iter,n)[_indexExpr.unroll(iter,n)];
	}
	else {
	  return _parent.unroll(iter,n)[_pindex];
	}
      }

      override void _esdl__doRandomize(_esdl__RandGen randGen) {
	static if (HAS_RAND_ATTRIB) {
	  if(stage is null) {
	    E val;
	    randGen.gen(val);
	    collate(val);
	  }
	}
	else {
	  assert(false, name());
	}
      }

      override void _esdl__doRandomize(_esdl__RandGen randGen, CstStage s) {
	static if (HAS_RAND_ATTRIB) {
	  assert (stage is s);
	  E val;
	  randGen.gen(val);
	  collate(val);
	}
	else {
	  assert(false, name());
	}
      }
      
      override E* getRef() {
	if(_indexExpr) {
	  return _parent.getRef(cast(size_t) _indexExpr.evaluate());
	}
	else {
	  return _parent.getRef(this._pindex);
	}
      }

      override long value() {
	if(_indexExpr) {
	  return *(_parent.getRef(_indexExpr.evaluate()));
	}
	else {
	  return *(_parent.getRef(this._pindex));
	}
      }

      RV flatten() {
	if (_indexExpr !is null) {
	  return _parent.flatten()[cast(size_t) _indexExpr.evaluate()];
	}
	else {
	  return this;
	}
      }

      bool refresh(CstStage s, Buddy buddy) {
	static if (HAS_RAND_ATTRIB) {
	  if (_indexExpr !is null) {
	    return flatten().refresh(s, buddy);
	  }
	  else {
	    assert(stage(), "Stage not set for " ~ this.name());
	    if(this.isRand && s is stage()) {
	      return false;
	    }
	    else if((! this.isRand) ||
		    this.isRand && stage().solved()) { // work with the value
	      return refreshVal(buddy);
	    }
	    else {
	      assert(false, "Constraint evaluation in wrong stage");
	    }
	  }
	}
	else {
	  return refreshVal(buddy);
	}
      }
  
      private bool refreshVal(Buddy buddy) {
	auto val = *(getRef());
	if (_valvec.isNull ||
	    val != _refreshedVal) {
	  _valvec.buildVec(buddy, val);
	  _refreshedVal = val;
	  return true;
	}
	else {
	  return false;
	}
      }
  
      BddVec getBDD(CstStage s, Buddy buddy) {
	static if (HAS_RAND_ATTRIB) {
	  if (_indexExpr !is null) {
	    auto dvec = _parent[cast(size_t) _indexExpr.evaluate()];
	    return dvec.getBDD(s, buddy);
	  }
	  else {
	    assert(stage(), "Stage not set for " ~ this.name());
	    if(this.isRand && s is stage()) {
	      return bddvec(buddy);
	      // return _domvec;
	    }
	    else if((! this.isRand) ||
		    this.isRand && stage().solved()) { // work with the value
	      return _valvec;
	    }
	    else {
	      assert(false, "Constraint evaluation in wrong stage");
	    }
	  }
	}
	else {
	  return _valvec;
	}
      }

      override void collate(ulong v, int word = 0) {
	static if (HAS_RAND_ATTRIB) {
	  E* var = getRef();
	  static if(isIntegral!E) {
	    if(word == 0) {
	      *var = cast(E) v;
	    }
	    else {
	      assert(false, "word has to be 0 for integrals");
	    }
	  }
	  else {
	    (*var)._setNthWord(v, word);
	  }
	}
	else {
	  assert(false);
	}
      }

      bool isConst() {
	return false;
      }

      bool isOrderingExpr() {
	return false;		// only CstVecOrderingExpr return true
      }

      void setBddContext(CstEquation eqn,
			 ref CstDomain[] vars,
			 ref CstDomain[] vals,
			 ref CstIteratorBase iter,
			 ref CstDomain[] deps) {
	static if (is (R: _esdl__norand)) {
	  vals ~= this;
	}
	else {
	  bool listed;
	  foreach (var; vars) {
	    if (var is this) {
	      listed = true;
	      break;
	    }
	  }
	  if (listed is false) {
	    vars ~= this;
	  }
	}

	if (_indexExpr !is null) {
	  // Here we need to put the parent as a dep for the eqn
	  // and since this prim needs resolution, the constituents of
	  // the indexExpr need to trigger a function that finds out
	  // whether the _indexExpr has been fully resolved or
	  // not. When the indexExpr gets resolved, it should inform
	  // the parent about resolution which in turn should inform
	  // the eqn that it can go ahead
	  _indexExpr.setBddContext(eqn, deps, vals, iter, deps);
	}
      }

      bool getIntMods(ref IntRangeModSet modSet) {
	return true;
      }
    }

// Arrays (Multidimensional arrays as well)
// template CstVecArrBase(T, int I, int N=0)
//   if(_esdl__ArrOrder!(T, I, N) != 0) {
//   alias CstVecArrBase = CstVecArrBase!(typeof(T.tupleof[I]),
// 					   getRandAttr!(T, I), N);
// }

abstract class CstVecArrBase(V, alias R, int N=0)
  if(_esdl__ArrOrder!(V, N) != 0): CstVecPrim
{
  enum HAS_RAND_ATTRIB = (! __traits(isSame, R, _esdl__norand));

  alias L = ElementTypeN!(V, N);
  alias E = ElementTypeN!(V, N+1);

  static if (_esdl__ArrOrder!(V, N+1) == 0) {
    alias EV = CstVec!(V, R, N+1);
  }
  else {
    alias EV = CstVecArr!(V, R, N+1);
  }

  EV[] _elems;

  string _name;
  override string name() {
    return _name;
  }

  static if (HAS_RAND_ATTRIB) {
    CstVecPrim[] _preReqs;
  }

  bool isVarArr() {
    return true;
  }

  BDD getPrimBdd(Buddy buddy) {
    return buddy.one();
  }

  void resetPrimeBdd() { }

  // override CstVec2VecExpr opIndex(CstVecExpr indx) {
  //   return new CstVec2VecExpr(this, indx, CstBinVecOp.INDXINDEX);
  // }

  bool isRand() {
    assert(false, "isRand not implemented for CstVecArrBase");
  }

  void collate(ulong v, int word = 0) {
    assert(false, "value not implemented for CstVecArrBase");
  }

  uint domIndex() {
    assert(false, "domIndex not implemented for CstVecArrBase");
  }

  void domIndex(uint s) {
    assert(false, "domIndex not implemented for CstVecArrBase");
  }

  uint bitcount() {
    assert(false, "bitcount not implemented for CstVecArrBase");
  }

  bool signed() {
    assert(false, "signed not implemented for CstVecArrBase");
  }

  ref BddVec bddvec(Buddy buddy) {
    assert(false, "bddvec not implemented for CstVecArrBase");
  }

  // void bddvec(BddVec b) {
  //   assert(false, "bddvec not implemented for CstVecArrBase");
  // }

  void solveBefore(CstVecPrim other) {
    static if (HAS_RAND_ATTRIB) {
      other.addPreRequisite(this);
    }
    else {
      assert(false);
    }
  }

  void addPreRequisite(CstVecPrim prim) {
    static if (HAS_RAND_ATTRIB) {
      _preReqs ~= prim;
    }
    else {
      assert(false);
    }
  }

}

template CstVecArr(T, int I, int N=0)
  if(_esdl__ArrOrder!(T, I, N) != 0) {
  alias CstVecArr = CstVecArr!(typeof(T.tupleof[I]),
			       getRandAttr!(T, I), N);
}

// Arrays (Multidimensional arrays as well)
class CstVecArr(V, alias R, int N=0)
  if(N == 0 && _esdl__ArrOrder!(V, N) != 0):
    CstVecArrBase!(V, R, N)
      {
	alias RV = typeof(this);
	CstVecLen!RV _arrLen;

	alias RAND=R;

	V* _var;
	_esdl__Solver _parent;
    
	void _esdl__setValRef(ref V var) {
	  _var = &var;
	}
      
	this(string name, ref V var, _esdl__Solver parent) {
	  // import std.stdio;
	  // writeln("New ", name);
	  _name = name;
	  _var = &var;
	  _parent = parent;
	  _arrLen = new CstVecLen!RV(name ~ ".len", this);
	  _relatedIndxs ~= _arrLen;
	  getSolverRoot().addDomain(_arrLen);
	}

	bool isConcrete() {
	  return true; 		// N == 0
	}

	_esdl__Solver getSolverRoot() {
	  assert(_parent !is null);
	  return _parent.getSolverRoot();
	}
	
	CstVecPrim[] preReqs() {
	  static if (HAS_RAND_ATTRIB) {
	    return _preReqs;		// N = 0 -- no _parent
	  }
	  else {
	    return [];
	  }
	}

	CstIteratorBase[] iterVars() {
	  return [];		// N = 0 -- no _parent
	}

	CstIteratorBase getIterator() {
	  return null;		// N = 0 -- no _parent
	}

	static if (HAS_RAND_ATTRIB) {
	  EV[] getDomainElems(long indx) {
	    if (indx < 0) {
	      if (_arrLen.isResolved()) return _elems[0..(cast(size_t) _arrLen.evaluate())];
	      else return _elems;
	    }
	    else return [_elems[cast(size_t) indx]];
	  }
	}

	// CstDomain[] getRndDomains(bool resolved) {
	//   static if (false) {	// This function can only be there for leaf nodes
	//     static if (HAS_RAND_ATTRIB) {
	//       CstDomain[] domains;
	//       foreach(elem; _elems) {
	// 	domains ~= elem;
	//       }
	//       return domains;
	//     }
	//     else {
	//       return [];
	//     }
	//   }
	//   else {
	//     assert(false);
	//   }
	// }

	CstDomain[] getDomainLens(bool resolved) {
	  static if (HAS_RAND_ATTRIB) {
	    CstDomain[] domains;
	    if(_arrLen.isRand) domains ~= _arrLen;
	    return domains;
	  }
	  else {
	    return [];
	  }
	}
    
	RV unroll(CstIteratorBase iter, uint n) {
	  return this;
	}

	RV flatten() {
	  return this;
	}

	bool parentLenIsUnresolved() {
	  return false;		// no parent
	}

	CstDomain[] unresolvedIndxs() {
	  CstDomain[] indxs;
	  foreach (indx; _relatedIndxs) {
	    if (! indx.solved()) {
	      bool add = true;
	      foreach (l; indxs) {
		if (l is indx) add = false;
		break;
	      }
	      if (add) indxs ~= indx;
	    }
	  }
	  return indxs;
	}

	bool hasUnresolvedIndx() {
	  foreach (domain; _relatedIndxs) {
	    if (! domain.solved()) {
	      return true;
	    }
	  }
	  return false;		// N=0 -- no _parent
	}
      
	CstDomain[] parentUnresolvedIndxs() {
	  return [];		// no parent
	}

	static private auto getRef(A, N...)(ref A arr, N indx)
	  if(isArray!A && N.length > 0 && isIntegral!(N[0])) {
	    static if(N.length == 1) return &(arr[indx[0]]);
	    else {
	      return getRef(arr[indx[0]], indx[1..$]);
	    }
	  }

	auto getRef(J...)(J indx) if(isIntegral!(J[0])) {
	  return getRef(*_var, cast(size_t) indx);
	}

	static if (HAS_RAND_ATTRIB) {
	  static private void setLen(A, N...)(ref A arr, size_t v, N indx)
	    if(isArray!A) {
	      static if(N.length == 0) {
		static if(isDynamicArray!A) {
		  arr.length = v;
		  // import std.stdio;
		  // writeln(arr, " indx: ", N.length);
		}
		else {
		  assert(false, "Can not set length of a fixed length array");
		}
	      }
	      else {
		// import std.stdio;
		// writeln(arr, " indx: ", N.length);
		setLen(arr[indx[0]], v, indx[1..$]);
	      }
	    }

	  void buildElements(size_t v=size_t.max) {
	    if (v == size_t.max) {
	      v = getLen();
	    }
	    size_t currLen = _elems.length;
	    // import std.stdio;
	    // writeln("Length was ", currLen, " new ", v);
	    if (currLen < v) {
	      _elems.length = v;
	      for (size_t i=currLen; i!=v; ++i) {
		import std.conv: to;
		_elems[i] = new EV(_name ~ "[#" ~ i.to!string() ~ "]",
				   this, cast(uint) i);
	      }
	    }
	  }
	
	  void setLen(N...)(size_t v, N indx) {
	    static if (HAS_RAND_ATTRIB) {
	      static if (N.length == 0) {
		buildElements(v);
	      }
	      setLen(*_var, v, indx);
	    }
	    else {
	      assert(false);
	    }
	  }

	}
	else {
	  void setLen(N...)(size_t v, N indx) {
	    // setLen(*_var, v, indx);
	    assert(false, "Can not set value for VarVecArr");
	  }
	}

	static private size_t getLen(A, N...)(ref A arr, N indx) if(isArray!A) {
	  static if(N.length == 0) return arr.length;
	  else {
	    if (arr.length == 0) return 0;
	    else return getLen(arr[indx[0]], indx[1..$]);
	  }
	}

	size_t getLen(N...)(N indx) {
	  return getLen(*_var, indx);
	}

	bool isUnrollable() {
	  foreach (var; _relatedIndxs) {
	    if (! var.solved()) return false;
	  }
	  return true;
	}

	CstDomain[] _relatedIndxs;
	void addRelatedIndx(CstDomain domain) {
	  foreach (var; _relatedIndxs) {
	    if (domain is var) {
	      return;
	    }
	  }
	  _relatedIndxs ~= domain;
	}
      
	EV opIndex(CstVecExpr indx) {
	  foreach (domain; indx.getRndDomains(false)) {
	    addRelatedIndx(domain);
	  }
	  if(indx.isConst() && _arrLen.solved()) {
	    // resolve only if the length has been resolved yet
	    // And when the length is resolved, we must make sure that
	    // unrolling of iterator takes care of such elements as
	    // well which are not explicitly onvoking iterators
	    assert(_elems.length > 0, "_elems for expr " ~ this.name() ~
		   " have not been built");
	    return _elems[cast(size_t) indx.evaluate()];
	  }
	  else {
	    return new EV(name ~ "[" ~ indx.name() ~ "]", this, indx);
	  }
	}

	EV opIndex(size_t indx) {
	  assert(_elems[indx]._indexExpr is null);
	  return _elems[indx];
	}

	void _esdl__doRandomize(_esdl__RandGen randGen) {
	  static if (HAS_RAND_ATTRIB) {
	    assert(arrLen !is null);
	    for(size_t i=0; i != arrLen.evaluate(); ++i) {
	      this[i]._esdl__doRandomize(randGen);
	    }
	  }
	  else {
	    assert(false);
	  }
	}

	void _esdl__doRandomize(_esdl__RandGen randGen, CstStage s) {
	  static if (HAS_RAND_ATTRIB) {
	    // assert (stage is s);
	    assert (arrLen !is null);
	    for(size_t i=0; i != arrLen.evaluate(); ++i) {
	      this[i]._esdl__doRandomize(randGen);
	    }
	  }
	  else {
	    assert(false);
	  }
	}

	auto elements() {
	  auto iter = arrLen.makeIterVar();
	  return this[iter];
	}

	auto iterator() {
	  auto iter = arrLen.makeIterVar();
	  return iter;
	}

	CstVecLen!RV length() {
	  return _arrLen;
	}

	CstVecLen!RV arrLen() {
	  return _arrLen;
	}

	void _esdl__reset() {
	  _arrLen._esdl__reset();
	  foreach(elem; _elems) {
	    if(elem !is null) {
	      elem._esdl__reset();
	    }
	  }
	}

	size_t maxArrLen() {
	  static if (HAS_RAND_ATTRIB) {
	    static if(isStaticArray!L) {
	      return L.length;
	    }
	    else {
	      return getRandAttrN!(R, N);
	    }
	  }
	  else {
	    return L.length;
	  }
	}

	// void setBddContext(CstEquation eqn,
	// 		   ref CstDomain[] vars,
	// 		   ref CstDomain[] vals,
	// 		   ref CstIteratorBase iter,
	// 		   ref CstDomain[] deps) {
	//   static if (is (R: _esdl__norand)) {
	//     vals ~= this;
	//   }
	//   else {
	//     bool listed;
	//     foreach (var; vars) {
	//       if (var is this) {
	// 	listed = true;
	// 	break;
	//       }
	//     }
	//     if (listed is false) {
	//       vars ~= this;
	//     }
	//   }
	// }
      }

class CstVecArr(V, alias R, int N=0)
  if(N != 0 && _esdl__ArrOrder!(V, N) != 0):
    CstVecArrBase!(V, R, N)
      {
	import std.traits;
	import std.range;
	import esdl.data.bvec;
	alias P = CstVecArr!(V, R, N-1);
	P _parent;
	CstVecExpr _indexExpr = null;
	int _pindex = 0;

	alias RV = typeof(this);
	CstVecLen!RV _arrLen;

	alias RAND=R;
      
	this(string name, P parent, CstVecExpr indexExpr) {
	  // import std.stdio;
	  // writeln("New ", name);
	  assert(parent !is null);
	  _name = name;
	  _parent = parent;
	  _indexExpr = indexExpr;
	  _arrLen = new CstVecLen!RV(name ~ ".len", this);
	  _relatedIndxs ~= _arrLen;
	  // addDomain only for concrete elements
	  // getSolverRoot().addDomain(_arrLen);
	}

	this(string name, P parent, uint index) {
	  // import std.stdio;
	  // writeln("New ", name);
	  assert(parent !is null);
	  _name = name;
	  _parent = parent;
	  // _indexExpr = _esdl__cstVal(index);
	  _pindex = index;
	  _arrLen = new CstVecLen!RV(name ~ ".len", this);
	  _relatedIndxs ~= _arrLen;
	  getSolverRoot().addDomain(_arrLen);
	}

	bool isConcrete() {
	  return (_indexExpr is null);
	}

	_esdl__Solver getSolverRoot() {
	  assert(_parent !is null);
	  return _parent.getSolverRoot();
	}
	
	CstVecPrim[] preReqs() {
	  CstVecPrim[] req;
	  static if (HAS_RAND_ATTRIB) {
	    req = _preReqs ~ _parent.arrLen();
	  }
	  if(_indexExpr) {
	    return req ~ _indexExpr.preReqs() ~ _parent.preReqs();
	  }
	  else {
	    return req ~ _parent.preReqs();
	  }
	}

	CstIteratorBase[] iterVars() {
	  if(_indexExpr) {
	    return _parent.iterVars() ~ _indexExpr.iterVars(); // ~ _arrLen.makeIterVar();
	  }
	  else {
	    return _parent.iterVars();
	  }
	}

	CstIteratorBase getIterator() {
	  auto piter = _parent.getIterator();
	  if (piter !is null) return piter;
	  else {
	    if (_indexExpr) {
	      return _indexExpr.getIterator();
	    }
	    else return null;
	  }
	}

	bool parentLenIsUnresolved() {
	  return (! _parent._arrLen.solved());
	}

	CstDomain[] unresolvedIndxs() {
	  CstDomain[] indxs;
	  foreach (indx; _relatedIndxs) {
	    if (! indx.solved()) {
	      bool add = true;
	      foreach (l; indxs) {
		if (l is indx) add = false;
		break;
	      }
	      if (add) indxs ~= indx;
	    }
	  }
	  return indxs;
	}

	bool hasUnresolvedIndx() {
	  foreach (domain; _relatedIndxs) {
	    if (! domain.solved()) {
	      return true;
	    }
	  }
	  return _parent.hasUnresolvedIndx();
	}

	CstDomain[] parentUnresolvedIndxs() {
	  return [_parent._arrLen];
	}

	EV[] getDomainElems(size_t indx) {
	  EV[] elems;
	  static if (HAS_RAND_ATTRIB) {
	    if(_indexExpr) {
	      foreach(pp; _parent.getDomainElems(-1)) {
		if(indx < 0) {
		  if (pp._arrLen.isResolved()) elems ~= pp._elems[0..cast(size_t)pp._arrLen.evaluate()];
		  else elems ~= pp._elems;
		}
		else elems ~= pp._elems[indx];
	      }
	    }
	    else {
	      foreach(pp; _parent.getDomainElems(_pindex)) {
		if(indx < 0) {
		  if (pp._arrLen.isResolved()) elems ~= pp._elems[0..cast(size_t)pp._arrLen.evaluate()];
		  else elems ~= pp._elems;
		}
		else elems ~= pp._elems[indx];
	      }
	    }
	  }
	  return elems;
	}
    
	// This is slightly tricky in case we are pointing directly to
	// just one element of the array, this function should return just
	// that element. But it could be that the index or an upper
	// hierarchy index is not a constant, but an iterator or a
	// randomized epression. In that case, we shall have to return
	// more primary elements
	// CstDomain[] getRndDomains(bool resolved) {
	// 	CstDomain[] domains;
	// 	static if (HAS_RAND_ATTRIB) {
	// 	  if(_indexExpr) {
	// 	    domains = _indexExpr.getRndDomains(resolved);
	// 	    foreach(pp; _parent.getDomainElems(-1)) {
	// 	      domains ~= pp;
	// 	    }
	// 	  }
	// 	  else {
	// 	    foreach(pp; _parent.getDomainElems(_pindex)) {
	// 	      domains ~= pp;
	// 	    }
	// 	  }
	// 	}
	// 	else {
	// 	  domains ~= _parent.getDomainLens();
	// 	  if(_indexExpr) {
	// 	    domains ~= _indexExpr.getRndDomains(resolved) ~ _parent.getDomainLens(resolved);
	// 	  }
	// 	}
	// 	return domains;
	// }

	CstDomain[] getDomainLens(bool resolved) {
	  // if(_pindex.iterVars.length is 0)
	  if(_indexExpr is null) {
	    return [_parent[_pindex].arrLen()];
	    // return domains ~ _parent[_pindex].getDomainLens(resolved);
	  }
	  if (_indexExpr.isConst() || resolved) {
	    CstDomain[] domains;
	    domains ~= _parent[cast(size_t) _indexExpr.evaluate()].getDomainLens(resolved);
	    return domains;
	  }
	  else {
	    CstDomain[] domains;
	    // import std.stdio;
	    // writeln(_parent.name(), " ", p.name());
	    domains = _indexExpr.getRndDomains(resolved);
	    foreach(pp; _parent.getDomainElems(-1)) {
	      domains ~= pp.getDomainLens(resolved);
	    }
	    return domains;
	  }
	}

	RV flatten() {
	  if (_indexExpr !is null) {
	    return _parent.flatten()[cast(size_t)_indexExpr.evaluate()];
	  }
	  else {
	    return this;
	  }
	}

	RV unroll(CstIteratorBase iter, uint n) {
	  bool found = false;
	  foreach(var; iterVars()) {
	    if(iter is var) {
	      found = true;
	      break;
	    }
	  }
	  if(! found) {
	    return this;
	  }
	  else if(_indexExpr) {
	    return _parent.unroll(iter,n)[_indexExpr.unroll(iter,n)];
	  }
	  else {
	    return _parent.unroll(iter,n)[_pindex];
	  }
	}

	static private size_t getLen(A, N...)(ref A arr, N indx) if(isArray!A) {
	  static if(N.length == 0) return arr.length;
	  else {
	    return getLen(arr[indx[0]], indx[1..$]);
	  }
	}

	static if (HAS_RAND_ATTRIB) {
	  static private void setLen(A, N...)(ref A arr, size_t v, N indx)
	    if(isArray!A) {
	      static if(N.length == 0) {
		static if(isDynamicArray!A) {
		  arr.length = v;
		  // import std.stdio;
		  // writeln(arr, " indx: ", N.length);
		}
		else {
		  assert(false, "Can not set length of a fixed length array");
		}
	      }
	      else {
		// import std.stdio;
		// writeln(arr, " indx: ", N.length);
		setLen(arr[indx[0]], v, indx[1..$]);
	      }
	    }

	  void buildElements(size_t v=size_t.max) {
	    if (v == size_t.max) {
	      v = getLen();
	    }
	    size_t currLen = _elems.length;
	    // import std.stdio;
	    // writeln("Length was ", currLen, " new ", v);
	    if (currLen < v) {
	      _elems.length = v;
	      for (size_t i=currLen; i!=v; ++i) {
		import std.conv: to;
		_elems[i] = new EV(_name ~ "[#" ~ i.to!string() ~ "]",
				   this, cast(uint) i);
	      }
	    }
	  }

	  void setLen(N...)(size_t v, N indx) {
	    static if (N.length == 0) {
	      buildElements(v);
	    }
	    _parent.setLen(v, _pindex, indx);
	  }
	}

	size_t getLen(N...)(N indx) {
	  return _parent.getLen(_pindex, indx);
	}

	static private auto getRef(A, N...)(ref A arr, N indx)
	  if(isArray!A && N.length > 0 && isIntegral!(N[0])) {
	    static if(N.length == 1) return &(arr[indx[0]]);
	    else {
	      return getRef(arr[indx[0]], indx[1..$]);
	    }
	  }

	auto getRef(N...)(N indx) if(isIntegral!(N[0])) {
	  if(_indexExpr) {
	    assert(_indexExpr.isConst());
	    return _parent.getRef(cast(size_t) _indexExpr.evaluate(), indx);
	  }
	  else {
	    return _parent.getRef(this._pindex, indx);
	  }
	}

	bool isUnrollable() {
	  foreach (var; _relatedIndxs) {
	    if (! var.solved()) return false;
	  }
	  return true;
	}

	CstDomain[] _relatedIndxs;
	void addRelatedIndx(CstDomain domain) {
	  foreach (var; _relatedIndxs) {
	    if (domain is var) {
	      return;
	    }
	  }
	  _relatedIndxs ~= domain;
	}
      
	EV opIndex(CstVecExpr indx) {
	  foreach (domain; indx.getRndDomains(false)) {
	    addRelatedIndx(domain);
	  }
	  if(indx.isConst()) {
	    assert(_elems.length > 0, "_elems for expr " ~ this.name() ~
		   " have not been built");
	    // if(indx.evaluate() >= _elems.length || indx.evaluate() < 0 || _elems is null) {
	    // 	import std.stdio;
	    // 	writeln(this.name(), ":", indx.evaluate());
	    // }
	    // import std.stdio;
	    // writeln(indx.evaluate());
	    return _elems[cast(size_t) indx.evaluate()];
	  }
	  else {
	    // static if(isStaticArray!E) {
	    //   // static array
	    return new EV(name ~ "[" ~ indx.name() ~ "]", this, indx);
	    // }
	    // else static if(isDynamicArray!E) {
	    //   // dynamic array
	    //   return new EV(name ~ "[" ~ indx.name() ~ "]", this, indx);
	    // }
	    // else {
	    //   return new EV(name ~ "[" ~ indx.name() ~ "]", this, indx);
	    // }
	  }
	}

	EV opIndex(size_t indx) {
	  assert(_elems[indx]._indexExpr is null);
	  return _elems[indx];
	}

	void _esdl__doRandomize(_esdl__RandGen randGen) {
	  static if (HAS_RAND_ATTRIB) {
	    assert(arrLen !is null);
	    for(size_t i=0; i != arrLen.evaluate(); ++i) {
	      this[i]._esdl__doRandomize(randGen);
	    }
	  }
	  else {
	    assert(false);
	  }
	}

	void _esdl__doRandomize(_esdl__RandGen randGen, CstStage s) {
	  static if (HAS_RAND_ATTRIB) {
	    // assert (stage is s);
	    assert (arrLen !is null);
	    for (size_t i=0; i != arrLen.evaluate(); ++i) {
	      this[i]._esdl__doRandomize(randGen);
	    }
	  }
	  else {
	    assert(false);
	  }
	}

	auto elements() {
	  auto indx = arrLen.makeIterVar();
	  return this[indx];
	}

	auto iterator() {
	  auto iter = arrLen.makeIterVar();
	  return iter;
	}

	CstVecLen!RV length() {
	  return _arrLen;
	}

	CstVecLen!RV arrLen() {
	  return _arrLen;
	}

	void _esdl__reset() {
	  _arrLen._esdl__reset();
	  foreach(elem; _elems) {
	    if(elem !is null) {
	      elem._esdl__reset();
	    }
	  }
	}

	size_t maxArrLen() {
	  static if (HAS_RAND_ATTRIB) {
	    static if(isStaticArray!L) {
	      return L.length;
	    }
	    else {
	      return getRandAttrN!(R, N);
	    }
	  }
	  else {
	    return L.length;
	  }
	}

	// void setBddContext(CstEquation eqn,
	// 		   ref CstDomain[] vars,
	// 		   ref CstDomain[] vals,
	// 		   ref CstIteratorBase iter,
	// 		   ref CstDomain[] deps) {
	//   static if (is (R: _esdl__norand)) {
	//     vals ~= this;
	//   }
	//   else {
	//     bool listed;
	//     foreach (var; vars) {
	//       if (var is this) {
	// 	listed = true;
	// 	break;
	//       }
	//     }
	//     if (listed is false) {
	//       vars ~= this;
	//     }

	//     if (_indexExpr !is null) {
	//       _indexExpr.setBddContext(eqn, deps, vals, iter, deps);
	//     }
	//   }
	// }
      }
