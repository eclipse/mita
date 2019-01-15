package org.eclipse.mita.base.typesystem.solver

import com.google.inject.Inject
import com.google.inject.Provider
import java.util.HashMap
import java.util.HashSet
import java.util.List
import java.util.Map
import java.util.Set
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.impl.BasicEObjectImpl
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.expressions.util.ExpressionUtils
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.ParameterWithDefaultValue
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.StdlibTypeRegistry
import org.eclipse.mita.base.typesystem.constraints.AbstractTypeConstraint
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint
import org.eclipse.mita.base.typesystem.constraints.ExplicitInstanceConstraint
import org.eclipse.mita.base.typesystem.constraints.FunctionTypeClassConstraint
import org.eclipse.mita.base.typesystem.constraints.JavaClassInstanceConstraint
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.infra.ConstraintGraph
import org.eclipse.mita.base.typesystem.infra.ConstraintGraphProvider
import org.eclipse.mita.base.typesystem.infra.Graph
import org.eclipse.mita.base.typesystem.infra.MitaBaseResource
import org.eclipse.mita.base.typesystem.infra.TypeClassUnifier
import org.eclipse.mita.base.typesystem.types.AbstractBaseType
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.IntegerType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeHole
import org.eclipse.mita.base.typesystem.types.TypeScheme
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.typesystem.types.UnorderedArguments
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtext.diagnostics.Severity
import org.eclipse.xtext.util.CancelIndicator

import static extension org.eclipse.mita.base.util.BaseUtils.force
import static extension org.eclipse.mita.base.util.BaseUtils.zip
import org.eclipse.mita.base.util.DebugTimer

/**
 * Solves coercive subtyping as described in 
 * Extending Hindley-Milner Type Inference with Coercive Structural Subtyping
 * Traytel et al., https://www21.in.tum.de/~nipkow/pubs/aplas11.pdf
 */
class CoerciveSubtypeSolver implements IConstraintSolver {	
	@Inject
	protected MostGenericUnifierComputer mguComputer
	
	@Inject
	protected Provider<ConstraintSystem> constraintSystemProvider;
	
	@Inject 
	protected Provider<Substitution> substitutionProvider;
	
	@Inject
	protected ConstraintGraphProvider constraintGraphProvider;
	
	@Inject
	protected StdlibTypeRegistry typeRegistry;
	
	val enableDebug = true;
	
	def CancelIndicator getCancelIndicatorOrNull(Resource resource) {
		if(resource instanceof MitaBaseResource) {
			return resource.cancelIndicator;
		}
		return null;
	}
	
	override ConstraintSolution solve(ConstraintSystem system, EObject typeResolutionOrigin) {
		val debugTimer = new DebugTimer();
		val debugOutput = enableDebug && typeResolutionOrigin.eResource.URI.lastSegment == "application.mita";
		
		val cancelInidicator = typeResolutionOrigin.eResource.getCancelIndicatorOrNull;		
		var currentSystem = system;
		var currentSubstitution = Substitution.EMPTY;
		if(typeResolutionOrigin.eIsProxy) {
			return new ConstraintSolution(system, currentSubstitution, #[new ValidationIssue(Severity.ERROR, "INTERNAL ERROR: typeResolutionOrigin must not be a proxy", typeResolutionOrigin, null, "")]);
		}
		var ConstraintSolution result = null;
		val issues = newArrayList;

		// do one simplification pass to solve equalities etc. then unify type classes
		debugTimer.start("simplify.1");
		val simplification1 = currentSystem.simplify(currentSubstitution, typeResolutionOrigin);
		if(cancelInidicator !== null && cancelInidicator.isCanceled()) {
			return null;
		}
		if(!simplification1.valid) {
			issues += simplification1.issues;
			if(simplification1?.system?.constraints.nullOrEmpty || simplification1?.substitution?.content?.entrySet.nullOrEmpty) {
				return new ConstraintSolution(currentSystem, simplification1.substitution, simplification1.issues);
			}
		}
		currentSystem = simplification1.system;
		currentSubstitution = simplification1.substitution;
		debugTimer.stop();
		
		debugTimer.start("tcc-unification");
		currentSystem = unifyTypeClassInstances(currentSystem);
		for(tcc: currentSystem.constraints.filter(FunctionTypeClassConstraint).force) {
			val typeClass = currentSystem.typeClasses.get(tcc.instanceOfQN);
			if(typeClass.mostSpecificGeneralization !== null) {
				val funTypeInstance = typeClass.mostSpecificGeneralization.instantiate(currentSystem).value;
				if(funTypeInstance instanceof FunctionType) {
					val typeThatShouldBeInstance = tcc.typ;
					currentSystem.addConstraint(new SubtypeConstraint(typeThatShouldBeInstance, funTypeInstance.from, new ValidationIssue('''CSS: 118''', null)));
					currentSystem.addConstraint(new EqualityConstraint(funTypeInstance.to, tcc.returnTypeTV, new ValidationIssue('''CSS: 124''', null)));
				}
			}
		}
		debugTimer.stop()
		
		debugTimer.start("solveloop")
		for(var i = 0; i < 10; i++) {
			if(cancelInidicator !== null && cancelInidicator.isCanceled()) {
				return null;
			}
			if(debugOutput) {
				println("------------------")
				println(currentSystem);
			}
			
			debugTimer.start("simplify." + (i + 2));
			val simplification = currentSystem.simplify(currentSubstitution, typeResolutionOrigin);
			if(cancelInidicator !== null && cancelInidicator.isCanceled()) {
				return null;
			}
			if(!simplification.valid) {
				issues += simplification.issues;
				if(simplification?.system?.constraints.nullOrEmpty || simplification?.substitution?.content?.entrySet.nullOrEmpty) {
					return new ConstraintSolution(currentSystem, simplification.substitution, simplification.issues);
				}
			}
			val simplifiedSystem = simplification.system;
			val simplifiedSubst = simplification.substitution;
			if(debugOutput) {
				println(simplification);
			}
			debugTimer.stop()
			
			debugTimer.start("solveSubtypeConstraints." + (i + 2));
			val solution = solveSubtypeConstraints(simplifiedSystem, simplifiedSubst, typeResolutionOrigin);
			if(cancelInidicator !== null && cancelInidicator.isCanceled()) {
				return null;
			}
			if(!solution.issues.empty) {
				issues += solution.issues;
				if(solution?.constraints?.constraints.nullOrEmpty || solution?.solution?.content?.entrySet.nullOrEmpty) {
					return new ConstraintSolution(simplifiedSystem, simplifiedSubst, issues);
				}
			}
			result = solution;
			currentSubstitution = result.solution;
			debugTimer.stop();
			
			debugTimer.start("substitute." + (i + 2));
			currentSystem = currentSubstitution.apply(result.constraints);
			debugTimer.stop();
		}
		debugTimer.stop()
		
		issues += validateSubtypes(currentSystem, typeResolutionOrigin);
		
		currentSubstitution.content.entrySet.filter[it.key instanceof TypeHole].forEach[th_t |
			val origin = if(th_t.key.origin.eIsProxy) {
				val proxy = th_t.key.origin as BasicEObjectImpl;
				typeResolutionOrigin.eResource.resourceSet.getEObject(proxy.eProxyURI, true);
			}
			else {
				th_t.key.origin;
			}
			issues += new ValidationIssue(Severity.INFO, '''«origin» has type «th_t.value»''', th_t.key.origin, null, "") 
		]
		
		println('''solve timing:\n«debugTimer»''')
		
		return new ConstraintSolution(currentSystem, currentSubstitution, issues);
	}
		
	def Iterable<ValidationIssue> validateSubtypes(ConstraintSystem system, EObject typeResolutionOrigin) {
		return system.constraints.filter(SubtypeConstraint).flatMap[
			if(!typeRegistry.isSubType(typeResolutionOrigin, it.subType, it.superType)) {
				#[it.errorMessage]
			}
			else {
				#[]
			}
		]
	}
	
	def ConstraintSystem unifyTypeClassInstances(ConstraintSystem system) {
		val result = new ConstraintSystem(system);
		result.typeClasses.replaceAll[__, tc | TypeClassUnifier.INSTANCE.unifyTypeClassInstancesStructure(result, tc)];
		return result;
	}
	
	protected def ConstraintSolution solveSubtypeConstraints(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin) {
		val debugOutput = enableDebug && typeResolutionOrigin.eResource.URI.lastSegment == "application.mita";
		
		val issues = newArrayList;
		
		val constraintGraphAndSubst = system.buildConstraintGraph(substitution, typeResolutionOrigin);
		if(!constraintGraphAndSubst.value.valid) {
			val failure = constraintGraphAndSubst.value;
			issues += failure.issues;
			//return new ConstraintSolution(system, failure.substitution, failure.issues);
		}
		val constraintGraph = constraintGraphAndSubst.key;
		val constraintGraphSubstitution = constraintGraphAndSubst.value.substitution;
		if(debugOutput) {
			println("------------------")
			println(constraintGraph.toGraphviz());
			println(constraintGraphSubstitution);
		}		
		val resolvedGraphAndSubst = constraintGraph.resolve(constraintGraphSubstitution, typeResolutionOrigin);
		val resolvedGraph = resolvedGraphAndSubst.key.key;
		val resolvedGraphSubstitution = resolvedGraphAndSubst.key.value;
		if(resolvedGraphSubstitution === null) {	
			return new ConstraintSolution(system, resolvedGraphSubstitution, resolvedGraphAndSubst.value);
		}
		if(debugOutput) {
			println("------------------")
			println(resolvedGraphSubstitution);
		}
		if(issues.empty) {
			val newEqualities = resolvedGraph.unify();
			system.nonAtomicConstraints.addAll(newEqualities);
		}
		return new ConstraintSolution(system, resolvedGraphSubstitution, (issues + resolvedGraphAndSubst.value).filterNull.toList);
	}
	
	protected def boolean isWeaklyUnifiable(ConstraintSystem system) {
		// TODO: implement me
		return true;
	}
	
	protected def SimplificationResult simplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin) {
		var resultSystem = system;
		var resultSub = substitution;
		var issues = newArrayList;
		while(resultSystem.hasNonAtomicConstraints()) {
			val constraintAndSystem = resultSystem.takeOneNonAtomic();
			val constraint = constraintAndSystem.key;
			val constraintSystem = constraintAndSystem.value;

			val simplification = doSimplify(constraintSystem, resultSub, typeResolutionOrigin, constraint);
			if(!simplification.valid) {
				issues += simplification.issues;
				// just throw out the constraint for now
				resultSystem = constraintSystem;
				//return SimplificationResult.failure(simplification.issue);
			}
			else {
				val witnessesNotWeaklyUnifyable = simplification.substitution.content.entrySet.filter[tv_t | tv_t.key != tv_t.value && tv_t.value.freeVars.exists[it == tv_t.key]].flatMap[#[it.key, it.value]].force;
				if(!witnessesNotWeaklyUnifyable.empty) {
					print("");
					issues += witnessesNotWeaklyUnifyable.map[new ValidationIssue(Severity.ERROR, "Types are recursive: " + witnessesNotWeaklyUnifyable.toString, it.origin, null, "")]; 
					witnessesNotWeaklyUnifyable.filter(TypeVariable).forEach[
						simplification.substitution.content.remove(it);
					]	
				}
				resultSub = simplification.substitution;
				resultSystem = resultSub.apply(simplification.system);
			}
		}
		
		return new SimplificationResult(resultSub, issues, resultSystem);
	}
		
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, ExplicitInstanceConstraint constraint) {
		val instance = constraint.typeScheme.instantiate(system);
		val instanceType = instance.value
		val resultSystem = system.plus(
			new EqualityConstraint(constraint.instance, instanceType, constraint.errorMessage)
		)
		return SimplificationResult.success(resultSystem, substitution);
	}
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, JavaClassInstanceConstraint constraint) {
		if(constraint.javaClass.isInstance(constraint.what)) {
			return SimplificationResult.success(system, substitution);
		}
		return SimplificationResult.failure(constraint.errorMessage);
	}
	
	@Accessors
	@EqualsHashCode
	private static class TypeClassConstraintResolutionResult {
		val Substitution sideEffectSubstitution;
		val List<AbstractTypeConstraint> sideEffectConstraints = newArrayList;
		val List<ValidationIssue> issues = newArrayList;
		val AbstractType functionType;
		val EObject function;
		val double distanceToTargetType;
		
		new(Substitution sideEffectSubstitution, Iterable<AbstractTypeConstraint> sideEffectConstraints, Iterable<ValidationIssue> issues, AbstractType functionType, EObject function, double distanceToTargetType) {
			this.sideEffectSubstitution = sideEffectSubstitution;
			this.sideEffectConstraints += sideEffectConstraints;
			this.issues += issues;
			this.functionType = functionType;
			this.function = function;
			this.distanceToTargetType = distanceToTargetType;
		}
		
		override toString() {
			if(issues.empty) {
				return '''«functionType» (dist: «distanceToTargetType»)'''				
			}
			else {
				return '''INVALID: «issues»'''
			}
		}
		
		def isValid() {
			return issues.empty;
		}
		
	}
	
	protected def handleDefaultParametersInTypeClassResolution(ConstraintSystem system, Substitution substitution, AbstractType refType, Operation fun) {
		if(refType instanceof ProdType) {
			val assignedArgs = refType.typeArguments
			if(assignedArgs.size < fun.parameters.size) {
				val mbDefaultParameterValues = fun.parameters.drop(assignedArgs.size).filter(ParameterWithDefaultValue);
				if(!mbDefaultParameterValues.empty && mbDefaultParameterValues.forall[it.defaultValue !== null]) {
					val defaultParameterTypes = mbDefaultParameterValues.map[system.getTypeVariable(it)].map[substitution.apply(it)]
					val args = assignedArgs + defaultParameterTypes;
					return new ProdType(refType.origin, refType.type, args);
				}
			}	
		}
		return refType;
	}
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, FunctionTypeClassConstraint constraint) {
		val refType = constraint.typ;
		val typeClass = system.typeClasses.get(constraint.instanceOfQN);
		if(typeClass !== null) {
			val unificationResults = typeClass.instances.entrySet.map[k_v | 
				val typRaw = k_v.key;
				val EObject fun = k_v.value;
				// typRaw might be a typeScheme (int32 -> b :: id: \T.T -> T)
				val typ_distance = if(typRaw instanceof TypeScheme) {
					typRaw.instantiate(system).value -> Double.POSITIVE_INFINITY
				} else {
					typRaw -> 0.0;
				}
				val typ = typ_distance.key;
				val distance = typ_distance.value;
				// handle named parameters: if _refType is unorderedArgs, sort them
				val prodType = if(refType instanceof UnorderedArguments) {
					if(fun instanceof Operation) {
						val sortedArgs = ExpressionUtils.getSortedArguments(fun.parameters, refType.argParamNamesAndValueTypes, 
							[it], [it.key], [
								if(it instanceof ParameterWithDefaultValue) {
									if(it.defaultValue !== null) { 
										return it.name -> substitution.apply(system.getTypeVariable(it.defaultValue));
									}
								} 
								return it.name -> null;
							]
						);
						if(sortedArgs.exists[it.value === null]) {
							return new TypeClassConstraintResolutionResult(Substitution.EMPTY, #[], #[constraint.errorMessage, new ValidationIssue(constraint._errorMessage, '''Too few arguments''')], typ, fun, distance);
						}
						new ProdType(refType.origin, new AtomicType(fun, fun.name), sortedArgs.map[it.value]);
					}
					else {
						return new TypeClassConstraintResolutionResult(Substitution.EMPTY, #[], #[constraint.errorMessage, new ValidationIssue(constraint._errorMessage, '''Can't use named parameters for non-operations''')], typ, fun, distance);
					}
				} else {
					// handle default values
					if(fun instanceof Operation) {
						system.handleDefaultParametersInTypeClassResolution(substitution, refType, fun);
					}
					else {
						refType;
					}
				}
				
				// two possible ways to be part of this type class:
				// - via subtype (uint8 < uint32)
				// - via instantiation/unification 
				if(typ instanceof FunctionType) {
					val mbUnification = mguComputer.compute(constraint._errorMessage, prodType, typ.from);
					if(mbUnification.valid) {
						return new TypeClassConstraintResolutionResult(mbUnification.substitution, #[], #[], typ, fun, distance);
					}
					
					val subtypeCheckResult = typeRegistry.isSubtypeOf(typeResolutionOrigin, prodType, typ.from);
					if(!subtypeCheckResult.invalid) {
						// TODO insert coercion
						return new TypeClassConstraintResolutionResult(Substitution.EMPTY, subtypeCheckResult.constraints, #[], typ, fun, distance + subtypeCheckResult.constraints.size);
					}
					
					return new TypeClassConstraintResolutionResult(null, #[], subtypeCheckResult.messages.map[new ValidationIssue(constraint.errorMessage, it)] + mbUnification.issues, typ, fun, distance);
				}

				return new TypeClassConstraintResolutionResult(null, #[], #[new ValidationIssue(constraint.errorMessage, '''«constraint.errorMessage» -> «typ» is not a function type''')], typ, fun, distance);
			].toList
			val processedResultsUnsorted = unificationResults.map[
				if(!it.valid) {
					return it;
				}
				val sub = substitution.apply(it.sideEffectSubstitution);
				val resultType = sub.applyToType(it.functionType);
				new TypeClassConstraintResolutionResult(sub, it.sideEffectConstraints, #[], resultType, it.function, it.distanceToTargetType + computeDistance(refType, resultType))
			].toList
			val processedResults = processedResultsUnsorted
				.sortBy[it.distanceToTargetType].toList;
			val result = processedResults.findFirst[
				it.valid 
			]
			if(result !== null) {
				val sub = result.sideEffectSubstitution;
				val newSystem = constraintSystemProvider.get();
				result.sideEffectConstraints.forEach[newSystem.addConstraint(it)];
				return constraint.onResolve(ConstraintSystem.combine(#[system, newSystem]), sub, result.function, result.functionType);
			}
		}
		return SimplificationResult.failure(#[
			new ValidationIssue(Severity.ERROR, '''«refType» not instance of «typeClass»''', constraint.errorMessage.target, constraint.errorMessage.feature, constraint.errorMessage.issueCode), 
			constraint.errorMessage
		]);
	}
		
	dispatch def double computeDistance(AbstractType type, FunctionType type2) {
		return doComputeDistance(type, type2.from);
	}
	dispatch def double computeDistance(AbstractType type, AbstractType type2) {
		return Double.POSITIVE_INFINITY;
	}
	
	dispatch def double doComputeDistance(TypeConstructorType type, TypeConstructorType type2) {
		return type.typeArguments.zip(type2.typeArguments).fold(0.0, [sum, t1_t2 | sum + t1_t2.key.doComputeDistance(t1_t2.value)]);
	}	
	dispatch def double doComputeDistance(AbstractType type, AbstractType type2) {
		if(type == type2) {
			return 0;
		}
		return Double.POSITIVE_INFINITY;
	}
	dispatch def double doComputeDistance(IntegerType type, IntegerType type2) {
		return Math.abs(type.widthInBytes - type2.widthInBytes);
	}
	
		
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, Object constraint) {
		SimplificationResult.failure(new ValidationIssue(Severity.ERROR, println('''INTERNAL ERROR: doSimplify not implemented for «constraint»'''), ""));
	}
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, Void constraint) {
		SimplificationResult.failure(new ValidationIssue(Severity.ERROR, println('''INTERNAL ERROR: doSimplify not implemented for null'''), ""));
	}
	
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, EqualityConstraint constraint) {
		val t1 = constraint.left;
		val t2 = constraint.right;
		if(t1 == t2) {
			return SimplificationResult.success(system, substitution);
		}
		return system.doSimplify(substitution, typeResolutionOrigin, constraint, t1, t2);
	}
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, EqualityConstraint constraint, TypeScheme t1, AbstractType t2) {
		val unification = mguComputer.compute(constraint._errorMessage, t1, t2);
		if(unification.valid) {
			return SimplificationResult.success(system, substitution.apply(unification.substitution));
		}
		return SimplificationResult.failure(unification.issues);
	}
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, EqualityConstraint constraint, AbstractType t1, TypeScheme t2) {
		return system.doSimplify(substitution, typeResolutionOrigin, constraint, t2, t1);
	}
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, EqualityConstraint constraint, TypeConstructorType t1, TypeConstructorType t2) {
		if(t1.class != t2.class || t1.typeArguments.size != t2.typeArguments.size) {
			return SimplificationResult.failure(constraint.errorMessage);
		}
		val newSystem = constraintSystemProvider.get();
		newSystem.addConstraint(new EqualityConstraint(t1.type, t2.type, constraint._errorMessage));
		t1.typeArguments.zip(t2.typeArguments).forEach[
			newSystem.addConstraint(new EqualityConstraint(it.key, it.value, constraint._errorMessage));
		]
		return SimplificationResult.success(ConstraintSystem.combine(#[system, newSystem]), substitution);
	}
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, EqualityConstraint constraint, AbstractType t1, AbstractType t2) {
		// unify
		val mgu = mguComputer.compute(constraint._errorMessage, t1, t2);
		if(!mgu.valid) {
			return SimplificationResult.failure(mgu.issues);
		}
		
		return SimplificationResult.success(mgu.substitution.apply(system), mgu.substitution.apply(substitution));
	}
		
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, SubtypeConstraint constraint) {
		val sub = constraint.subType;
		val top = constraint.superType;
		
		val result = doSimplify(system, substitution, typeResolutionOrigin, constraint, sub, top);
		return result;
	}
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, SubtypeConstraint constraint, SumType sub, SumType top) {
		return system._doSimplify(substitution, typeResolutionOrigin, constraint, sub as TypeConstructorType, top as TypeConstructorType);
	}
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, SubtypeConstraint constraint, TypeConstructorType sub, TypeConstructorType top) {
		if(sub.typeArguments.length !== top.typeArguments.length) {
			return SimplificationResult.failure(#[new ValidationIssue(constraint.errorMessage, '''«sub» and «top» differ in their type arguments'''), constraint.errorMessage]);
		}
		if(sub.class != top.class) {
			return SimplificationResult.failure(#[new ValidationIssue(constraint.errorMessage, '''«sub» and «top» are not constructed the same'''), constraint.errorMessage]);
		}
		
		val typeArgs = sub.typeArguments.zip(top.typeArguments).indexed;
		val nc = constraintSystemProvider.get();
		typeArgs.forEach[i_t1t2 |
			val tIdx = i_t1t2.key;
			val tSub = i_t1t2.value.key;
			val tTop = i_t1t2.value.value;
			nc.addConstraint(sub.getVariance(tIdx, tSub, tTop));
		]
		
		return SimplificationResult.success(ConstraintSystem.combine(#[system, nc]), substitution);
		
	}
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, SubtypeConstraint constraint, TypeVariable sub, TypeConstructorType top) {
		// expand-l:   a <= Ct1...tn
		val expansion = substitutionProvider.get() => [top.expand(system, it, sub)];
		val newSystem = expansion.apply(system.plus(new SubtypeConstraint(sub, top, constraint.errorMessage)));
		val newSubstitution = expansion.apply(substitution);
		return SimplificationResult.success(newSystem, newSubstitution);
	} 
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, SubtypeConstraint constraint, TypeConstructorType sub, TypeVariable top) {
		// expand-r:   Ct1...tn <= a
		val expansion = substitutionProvider.get() => [sub.expand(system, it, top)];
		val newSystem = expansion.apply(system.plus(new SubtypeConstraint(sub, top, constraint.errorMessage)));
		val newSubstitution = expansion.apply(substitution);
		return SimplificationResult.success(newSystem, newSubstitution);
	}
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, SubtypeConstraint constraint, AbstractBaseType sub, AbstractBaseType top) { 
		// eliminate:  U <= T
		val subtypeCheckResult = typeRegistry.isSubtypeOf(typeResolutionOrigin, sub, top);
		if(subtypeCheckResult.invalid) {
			return SimplificationResult.failure(constraint.errorMessage);
		} else {
			val newConstraints = subtypeCheckResult.constraints;
			if(newConstraints.empty) {
				return SimplificationResult.success(system, substitution);
			}
			val newSystem = constraintSystemProvider.get;
			newConstraints.forEach[newSystem.addConstraint(it)]
			return SimplificationResult.success(ConstraintSystem.combine(#[system, newSystem]), substitution);
		}
	}
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, SubtypeConstraint constraint, AbstractType sub, AbstractType top) { 
		// eliminate:  U <= T
		val subtypeCheckResult = typeRegistry.isSubtypeOf(typeResolutionOrigin, sub, top);
		if(subtypeCheckResult.invalid) {
			return SimplificationResult.failure(constraint.errorMessage);
		} else {
			val newConstraints = subtypeCheckResult.constraints;
			if(newConstraints.empty) {
				return SimplificationResult.success(system, substitution);
			}
			val newSystem = constraintSystemProvider.get;
			newConstraints.forEach[newSystem.addConstraint(it)]
			return SimplificationResult.success(ConstraintSystem.combine(#[system, newSystem]), substitution);
		}
	}
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, SubtypeConstraint constraint, TypeScheme sub, AbstractType top) {
		val vars_instance = sub.instantiate(system)
		val newSystem = system.plus(new SubtypeConstraint(vars_instance.value, top, constraint.errorMessage));
		return SimplificationResult.success(newSystem, substitution);
	}
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, SubtypeConstraint constraint, Object sub, Object top) {
		SimplificationResult.failure(new ValidationIssue(Severity.ERROR, println('''INTERNAL ERROR: doSimplify.SubtypeConstraint not implemented for «sub.class.simpleName» and «top.class.simpleName»'''), ""))
	}
		
	protected def Pair<ConstraintGraph, UnificationResult> buildConstraintGraph(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin) {
		val gWithCycles = constraintGraphProvider.get(system, typeResolutionOrigin);
		if(enableDebug) {
			println(gWithCycles.toGraphviz);
		}
		val finalState = new Object() {
			var Substitution s = substitution;
			var Boolean success = true;
			var Set<SubtypeConstraint> nonUnifiable = new HashSet();
			var Set<SubtypeConstraint> unifiedConstraints = new HashSet();
		}
		val Map<Integer, Set<SubtypeConstraint>> errorMessages = new HashMap();
		val gWithoutCycles = Graph.removeCycles(gWithCycles, [g, cycle | 
			val cycleNodes = cycle.flatMap[#[it.key, it.value]].force;
			val mgu = mguComputer.compute(cycle.map[it.key.value -> it.value.value]); 
			if(mgu.valid) {
				val newTypes = mgu.substitution.applyToTypes(cycleNodes.map[it.value]);
				finalState.s = finalState.s.apply(mgu.substitution);
				finalState.unifiedConstraints += cycleNodes.flatMap[g.nodeSourceConstraints.get(it.key)];
				val newType = newTypes.head;
				val newTypeIdx = g.addNode(newType);
				cycleNodes.map[it.key].toSet.forEach[ idx |
					errorMessages.computeIfAbsent(newTypeIdx, [new HashSet()]).addAll(gWithCycles.nodeSourceConstraints.getOrDefault(idx, new HashSet()))
				]
				return newTypeIdx;
			}
			else {
				finalState.success = false;
				val msg = '''CSS: Cyclic dependencies could not be resolved: «cycle.map[it.key.value + " -> "].join("")» -> «cycle.head.key.value»''';
				finalState.nonUnifiable += cycleNodes.flatMap[g.nodeSourceConstraints.getOrDefault(it.key, emptySet)];
				return g.addNode(new BottomType(null, msg));
			}
		])
		errorMessages.forEach[k, v|gWithoutCycles.nodeSourceConstraints.merge(k, v, [v1, v2 | (v1 + v2).toSet])]
		if(finalState.success) {
			return (gWithoutCycles -> UnificationResult.success(finalState.s));
		}
		else {
			finalState.nonUnifiable.removeAll(finalState.unifiedConstraints);
			return (gWithoutCycles -> new UnificationResult(
				finalState.s,
				finalState.nonUnifiable
					.filter[
						val str = typeRegistry.isSubtypeOf(typeResolutionOrigin, it.subType, it.superType);
						return !str.valid || !str.constraints.empty;
					]
					.map[it.errorMessage]
			));
		}
	}
	
	protected def Pair<Pair<ConstraintGraph, Substitution>, List<ValidationIssue>> resolve(ConstraintGraph graph, Substitution _subtitution, EObject typeResolutionOrigin) {
		val varIdxs = graph.typeVariables;
		var resultSub = _subtitution;
		val issues = newArrayList;
		for(vIdx : varIdxs) {
			val v = graph.nodeIndex.get(vIdx) as TypeVariable;
			val predecessors = graph.getBaseTypePredecessors(vIdx);
			val supremum = graph.getSupremum(predecessors);
			val successors = graph.getBaseTypeSuccecessors(vIdx);
			val infimum = graph.getInfimum(successors);
			val supremumIsValid = supremum !== null && successors.forall[ t | typeRegistry.isSubType(typeResolutionOrigin, supremum, t) ];
			val infimumIsValid = infimum !== null && predecessors.forall[ t | typeRegistry.isSubType(typeResolutionOrigin, t, infimum) ];
			
			if(!predecessors.empty) {
				if(supremumIsValid) {
					// assign-sup
					graph.replace(v, supremum);
					resultSub = resultSub.replace(v, supremum) => [add(v, supremum)];
				} else {
					//redo for debugging
					graph.getBaseTypePredecessors(vIdx);
					graph.getSupremum(predecessors);
					supremum !== null && successors.forall[ t | 
						typeRegistry.isSubType(typeResolutionOrigin, supremum, t)
					];
					val newIssues = ((graph.nodeSourceConstraints.get(vIdx)?.map[it.errorMessage]) ?: #[new ValidationIssue(Severity.ERROR, 
					'''Unable to find valid subtype for «v.name». Candidates «predecessors» don't share a super type (best guess: «supremum ?: "none"»)''', 
					v.origin, null, "")].toSet);
					issues += newIssues;
				}
			}
			else if(!successors.empty) {
				if(infimumIsValid) {
					// assign-inf
					graph.replace(v, infimum);
					resultSub = resultSub.replace(v, infimum) => [add(v, infimum)];
				} else {
					val newIssues = ((graph.nodeSourceConstraints.get(vIdx)?.map[it.errorMessage]) ?: #[new ValidationIssue(Severity.ERROR, 
					'''Unable to find valid subtype for «v.name». Candidates «successors» don't share a sub type (best guess: «infimum ?: "none"»)''',
					v.origin, null, "")]);
					issues += newIssues;
				}
			}
			if(enableDebug) {
				println(graph.toGraphviz);
			}
		}
		return (graph -> resultSub) -> issues;
	}
	
	protected def Iterable<AbstractTypeConstraint> unify(ConstraintGraph graph) {
		return graph.typeVariables.flatMap[ tv | 
			val inc = graph.incoming.get(tv);
			val out = graph.outgoing.get(tv);
			if(inc.size <= 1 && out.size <= 1) {
				return inc.map[it -> tv] + out.map[it -> tv];
			}
			return #[];
		]
		.map[graph.nodeIndex.get(it.key) -> graph.nodeIndex.get(it.value)]
		.map[new EqualityConstraint(it.key, it.value, new ValidationIssue(Severity.ERROR, "unification of graph", ""))]
	}
}


@FinalFieldsConstructor
@Accessors
class SimplificationResult extends UnificationResult {
	protected final ConstraintSystem system;
	
	static def success(ConstraintSystem s, Substitution sigma) {
		return new SimplificationResult(sigma, #[], s);
	}
	
	static def SimplificationResult failure(ValidationIssue issue) {
		return new SimplificationResult(null, #[issue], null);
	}
	static def SimplificationResult failure(Iterable<ValidationIssue> issues) {
		return new SimplificationResult(null, issues, null);
	}
	
	override toString() {
		if(isValid) {
			system.toString
		}
		else {
			""
		} + "\n" + super.toString()
	}
	
	def SimplificationResult or(SimplificationResult other) {
		if(this.valid) {
			if(other.valid) {
				return new SimplificationResult(this.substitution.apply(other.substitution), null, ConstraintSystem.combine(#[this.system, other.system]))
			}
			else {
				return this;
			}
		}
		else {
			if(other.valid) {
				return other;
			}
			else {
				return new SimplificationResult(null, this.issues + other.issues, null);
			}
		}
		
	}
}
