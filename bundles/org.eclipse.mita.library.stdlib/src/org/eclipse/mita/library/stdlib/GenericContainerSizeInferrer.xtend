package org.eclipse.mita.library.stdlib

import com.google.inject.Inject
import java.util.ArrayList
import java.util.Collections
import java.util.HashSet
import java.util.List
import java.util.Set
import java.util.function.BiFunction
import java.util.function.Function
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.expressions.AssignmentExpression
import org.eclipse.mita.base.expressions.AssignmentOperator
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.IntLiteral
import org.eclipse.mita.base.expressions.PrimitiveValueExpression
import org.eclipse.mita.base.types.NaryTypeAddition
import org.eclipse.mita.base.types.NullTypeSpecifier
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.PackageAssociation
import org.eclipse.mita.base.types.TypeExpressionSpecifier
import org.eclipse.mita.base.types.TypeReferenceSpecifier
import org.eclipse.mita.base.types.TypeSpecifier
import org.eclipse.mita.base.types.Variance
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.StdlibTypeRegistry
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint
import org.eclipse.mita.base.typesystem.constraints.MaxConstraint
import org.eclipse.mita.base.typesystem.constraints.SumConstraint
import org.eclipse.mita.base.typesystem.infra.InferenceContext
import org.eclipse.mita.base.typesystem.infra.TypeSizeInferrer
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.typesystem.types.LiteralNumberType
import org.eclipse.mita.base.typesystem.types.NumericAddType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.program.AbstractLoopStatement
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.inferrer.ProgramSizeInferrer
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.EcoreUtil2

import static org.eclipse.mita.program.inferrer.ProgramSizeInferrer.*

import static extension org.eclipse.mita.base.util.BaseUtils.force
import static extension org.eclipse.mita.base.util.BaseUtils.transpose
import static extension org.eclipse.mita.base.util.BaseUtils.zip

/**
 * Automatic unbinding of size types and recursion of data types.
 * Can only handle TypeConstructorTypes.
 * createConstraints dispatches on InferenceContext.obj, and .type,
 * create doCreateConstraints(InferenceContext c, ? extends EObject obj, ? extends AbstractType t) to implement.
 */
abstract class GenericContainerSizeInferrer implements TypeSizeInferrer {
	@Accessors
	TypeSizeInferrer delegate;
	@Inject
	protected StdlibTypeRegistry typeRegistry
	
	/**
	 * return indexes specifying which type arguments of appropriate TypeConstructorTypes are data and which are size.
	 * remember that the first argument of TCTs are atomic types that just reference the constructor.
	 */
	def List<Integer> getDataTypeIndexes();
	def List<Integer> getSizeTypeIndexes();
		
	def <T, S> S setTypeArguments(
		AbstractType type, 
		BiFunction<Integer, AbstractType, T> dataTypes, 
		BiFunction<Integer, AbstractType, T> sizeTypes,
		Function<T, AbstractType> extractType,
		BiFunction<AbstractType, Iterable<T>, S> combineSideEffects 
	) {
		if(type.class !== TypeConstructorType) {
			return combineSideEffects.apply(type, #[]);
		}
		val argType = type as TypeConstructorType; 
		
		val sizeTypeIndexes = sizeTypeIndexes;
		val dataTypeIndexes = dataTypeIndexes;
		val changed = new Object {
			boolean value = false;
		}
		val List<T> sideEffects = new ArrayList();
		val Iterable<Pair<AbstractType, Variance>> typeArgumentsAndVariances = argType.typeArgumentsAndVariances.indexed.map[
			val t_v = it.value;
			val i = it.key;
			val resultType = if(sizeTypeIndexes.contains(i)) {
				val t = sizeTypes.apply(i, t_v.key);
				sideEffects += t;
				extractType.apply(t);
			}
			else if(dataTypeIndexes.contains(i)) {
				val t = dataTypes.apply(i, t_v.key);
				sideEffects += t;
				extractType.apply(t);
			}
			else {
				t_v.key
			}
			if(resultType !== t_v.key) {
				changed.value = true;
			}
			resultType -> t_v.value 
		].force
		if(changed.value) {
			return combineSideEffects.apply(new TypeConstructorType(argType.origin, argType.name, typeArgumentsAndVariances), sideEffects);
		}
		else {
			return combineSideEffects.apply(type, #[]);
		}
	}
	
	override Pair<AbstractType, Iterable<EObject>> unbindSize(Resource r, ConstraintSystem system, EObject obj, AbstractType type) {
		return doUnbindSize(r, system, obj, type);
	}
	
	dispatch def Pair<AbstractType, Iterable<EObject>> doUnbindSize(Resource r, ConstraintSystem system, TypeReferenceSpecifier typeSpecifier, TypeConstructorType type) {
		return setTypeArguments(type, 
			[i, t| 
				delegate.unbindSize(r, system, typeSpecifier.typeArguments.get(i - 1), t)
			], 
			[i, t| system.newTypeVariable(t.origin) as AbstractType -> #[typeSpecifier.typeArguments.get(i - 1)] + typeSpecifier.typeArguments.get(i - 1).eAllContents.toIterable],
			[t_objs | t_objs.key],
			[t, objs| t -> objs.flatMap[it.value]]
		);
	}
	
	dispatch def Pair<AbstractType, Iterable<EObject>> doUnbindSize(Resource r, ConstraintSystem system, EObject obj, TypeConstructorType type) {
		return doUnbindSize(r, system, null, type);
	}
	
	dispatch def Pair<AbstractType, Iterable<EObject>> doUnbindSize(Resource r, ConstraintSystem system, Void obj, TypeConstructorType type) {
		return setTypeArguments(type, 
			[i, t| 
				delegate.unbindSize(r, system, null, t)
			], 
			[i, t| 
				system.newTypeVariable(t.origin) as AbstractType -> Collections.<EObject>emptyList() as Iterable<EObject>
			],
			[t_objs | t_objs.key],
			[t, objs| t -> objs.flatMap[it.value]]
		);
	}
	dispatch def Pair<AbstractType, Iterable<EObject>> doUnbindSize(Resource r, ConstraintSystem system, Void obj, AbstractType type) {
		return type -> #[];
	}
	dispatch def Pair<AbstractType, Iterable<EObject>> doUnbindSize(Resource r, ConstraintSystem system, EObject obj, AbstractType type) {
		return type -> #[];
	}
	
	
		
	override void createConstraints(InferenceContext c) {
		doCreateConstraints(c, c.obj, c.type);
	}
	
	dispatch def void doCreateConstraints(InferenceContext c, TypeExpressionSpecifier obj, AbstractType t) {
		val innerTv = c.system.getTypeVariable(obj.value);
		c.system.associate(innerTv, obj);
		val innerContext = new InferenceContext(c, obj.value, innerTv);
		createConstraints(innerContext);
	}
	
	dispatch def void doCreateConstraints(InferenceContext c, PrimitiveValueExpression obj, AbstractType t) {
		val tv = ProgramSizeInferrer.inferUnmodifiedFrom(c.system, obj, obj.value);
		createConstraints(new InferenceContext(c, obj.value, tv));
	}
	
	dispatch def void doCreateConstraints(InferenceContext c, IntLiteral obj, AbstractType t) {
		val u32 = typeRegistry.getTypeModelObject(obj, StdlibTypeRegistry.u32TypeQID);
		c.system.associate(new LiteralNumberType(obj, obj.value, c.system.getTypeVariable(u32)), obj);
	}
	
	dispatch def void doCreateConstraints(InferenceContext c, NaryTypeAddition obj, AbstractType t) {
		val summationType = new NumericAddType(obj, "typeAdd", t, obj.values.map[
			val innerTv = c.system.getTypeVariable(it);
			val innerContext = new InferenceContext(c, it, innerTv);			
			createConstraints(innerContext);
			
			c.system.getTypeVariable(it) as AbstractType -> Variance.INVARIANT
		]);
		c.system.associate(summationType, obj);
	}
	
	dispatch def void doCreateConstraints(InferenceContext c, TypeReferenceSpecifier obj, TypeConstructorType t) {
		// recurse on sizes
		val sizeTypeIndexes = sizeTypeIndexes;
		val dataTypeIndexes = dataTypeIndexes;
		(obj.typeArguments).indexed.zip(t.typeArguments.tail).forEach[ i_mt__tv |
			val i_mt = i_mt__tv.key;
			val i = i_mt.key + 1;
			val modelType = i_mt.value;
			val tv = i_mt__tv.value;
			val innerContext = new InferenceContext(c, modelType, c.system.getTypeVariable(modelType), tv);
			if(sizeTypeIndexes.contains(i)) {
				createConstraints(innerContext);
			}
			else if(dataTypeIndexes.contains(i)) {
				delegate.createConstraints(innerContext);
			}
			c.system.associate(tv, modelType);
		]
		c.system.associate(t, obj);
	}
	
	// default: delegate
	dispatch def void doCreateConstraints(InferenceContext c, EObject obj, AbstractType t) {
		delegate.createConstraints(c);
	}
	
	// create max constraints for all sizes
	override createConstraintsForMax(ConstraintSystem system, Resource r, MaxConstraint constraint) {
		if(constraint.arguments.forall[it instanceof TypeConstructorType]) {
			// constraint ~ f1 = max(array<f2, f3>, array<f4, f5>)
			// create f1 := array<f6, f7>, f6 = max(f2, f4), f7 = max(f3, f5)
			val target = constraint.target;
			val exampleType = constraint.types.head as TypeConstructorType;
			// take first arg without modification
			val targetTypeWithHoles = new TypeConstructorType(null, exampleType.typeArguments.head, exampleType.typeArgumentsAndVariances.tail.map[t_v|
				val type = t_v.key;
				val variance = t_v.value;
				val tv = system.newTypeVariable(null);
				return tv as AbstractType -> variance;
			]);
			system.addConstraint(new EqualityConstraint(target, targetTypeWithHoles, constraint._errorMessage))
			// [array<_, 1>, array<_, 2>]  => [[array, array], [_, _], [1, 2]]; 
			val typeArgumentsTransposed = constraint.arguments.map[it as TypeConstructorType].map[it.typeArguments].transpose;
			typeArgumentsTransposed.zip(targetTypeWithHoles.typeArguments).tail.forEach[ts_tv |
				// targetTypeWithHoles is created with all new type variables
				val tv = ts_tv.value as TypeVariable;
				val types = ts_tv.key;
				system.addConstraint(new MaxConstraint(tv, types, constraint._errorMessage))
			]
		}
	}
	
	// create sum constraints for all sizes
	override createConstraintsForSum(ConstraintSystem system, Resource r, SumConstraint constraint) {
		if(constraint.arguments.forall[it instanceof TypeConstructorType]) {
			// constraint ~ f1 = max(array<f2, f3>, array<f4, f5>)
			// create f1 := array<f6, f7>, f6 = max(f2, f4), f7 = max(f3, f5)
			val target = constraint.target;
			val exampleType = constraint.types.head as TypeConstructorType;
			// take first arg without modification
			val targetTypeWithHoles = new TypeConstructorType(null, exampleType.typeArguments.head, exampleType.typeArgumentsAndVariances.tail.map[t_v|
				val type = t_v.key;
				val variance = t_v.value;
				val tv = system.newTypeVariable(null);
				return tv as AbstractType -> variance;
			]);
			system.addConstraint(new EqualityConstraint(target, targetTypeWithHoles, constraint._errorMessage))
			// [array<_, 1>, array<_, 2>]  => [[array, array], [_, _], [1, 2]]; 
			val typeArgumentsTransposed = constraint.arguments.map[it as TypeConstructorType].map[it.typeArguments].transpose;
			typeArgumentsTransposed.zip(targetTypeWithHoles.typeArguments).tail.forEach[ts_tv |
				// targetTypeWithHoles is created with all new type variables
				val tv = ts_tv.value as TypeVariable;
				val types = ts_tv.key;
				system.addConstraint(new SumConstraint(tv, types, constraint._errorMessage))
			]
		}
	}
	
	override isFixedSize(TypeSpecifier ts) {
		return dispatchIsFixedSize(ts);
	}
	
	dispatch def boolean dispatchIsFixedSize(TypeExpressionSpecifier ts) {
		return StaticValueInferrer.infer(ts.value, []) !== null
	}
	dispatch def boolean dispatchIsFixedSize(TypeReferenceSpecifier ts) {
		val handledArgs = (dataTypeIndexes + sizeTypeIndexes).toSet;
		return ts.typeArguments.indexed.filter[handledArgs.contains(it.key)].forall[delegate.isFixedSize(it.value)];
	}
	dispatch def boolean dispatchIsFixedSize(NullTypeSpecifier ts) {
		return false;
	}
	
	override getZeroSizeType(InferenceContext c, AbstractType skeleton) {
		if(skeleton instanceof TypeConstructorType) {
			val result = setTypeArguments(
				skeleton, 
				[i, t| 
					delegate.getZeroSizeType(c, t);
				], [i, t|
					new LiteralNumberType(t.origin, 0, t);
				], [it], [t, innerTs |
					t
				])
			return result;
		}
		return skeleton;
	}
	
	/* Typing the following:
	 * type T<d1, ..., dn, s1 is T1, ..., sn is Tn>  // so d1 to dn are data parameters, s1 to sn are size parameters
	 * var x: T<d1, ..., dn, 10, _, ..., _, 20>
	 * var y: T<d1, ..., dn, 10, _, ..., _, 20>
	 * x += y;
	 * x = y;
	 * 
	 * size parameters:
	 * if si is bound in the type specifier of x, assign that
	 * else assign si to the max of all subsequent additions, so in a sequence
	 * x = y;
	 * x += z;
	 * x += z;
	 * x = y;
	 * x += z;
	 * x should have type max(y + z + z, y + z).
	 * on data parameters the same is done with the exception that for += we also take the maximum, since data is added but not expanded:
	 * ["asdf"] + ["foobar"] is array<string<6>, 2>, not array<string<10>, 2>.
	 */
	dispatch def void doCreateConstraints(InferenceContext c, VariableDeclaration variable, TypeConstructorType type) {
		ProgramSizeInferrer.inferUnmodifiedFrom(c.system, variable, variable.typeSpecifier);
		val handledArgs = (dataTypeIndexes + sizeTypeIndexes).toSet;
		val variableTypeSpecifier = variable.typeSpecifier;
		val fixedSizes = if(variableTypeSpecifier instanceof TypeReferenceSpecifier) {
			type.typeArguments.tail.zip(variableTypeSpecifier.typeArguments).indexed
				.map[(it.key + 1) -> it.value]
				.filter[handledArgs.contains(it.key + 1)]
				.filter[delegate.isFixedSize(it.value.value)]
				.map[it.key]
				.toSet
		}
		else {
			#{};
		}
		val variableSizes = new HashSet(handledArgs) => [removeAll(fixedSizes)];
		
		if(variableSizes.empty || !variable.writeable) {
			if(variable.initialization !== null) {	
				ProgramSizeInferrer.inferUnmodifiedFrom(c.system, variable, variable.initialization);
			}
			return;
		}
		
		val variableRoot = EcoreUtil2.getContainerOfType(variable, Program);
		
		val variableContainer = variable.eContainer;
		val initialSize = if(variable.initialization !== null) {
			c.system.getTypeVariable(variable.initialization);	
		} 
		else {
			getZeroSizeType(c, type);
		}
		
		val subsequentStatements = if(variableContainer instanceof Program) {
			variableContainer.functionDefinitions + variableContainer.eventHandlers;
		}
		else {
			// the container contains variable, so we can drop until we find the variable, then skip the variable itself
			variableContainer.eContents.dropWhile[it !== variable].tail
		}
		val totalSize = createConstraintsForMutating(c, variable, variableSizes, subsequentStatements, initialSize);
		c.system.associate(totalSize, variable);
	}
		
		def AbstractType createConstraintsForMutating(InferenceContext c, VariableDeclaration variable, Set<Integer> variableSizes, Iterable<EObject> objects, AbstractType runningSize) {
			objects.fold(runningSize, [ rs, obj |
				doCreateConstraintsForMutating(c, variable, variableSizes, rs, obj);
			])
		}
		
		def boolean isOnLeftHandSide(VariableDeclaration v, AssignmentExpression assignment) {
			return (#[assignment.varRef] + assignment.varRef.eAllContents.toIterable)
				.filter(ElementReferenceExpression)
				.exists[it.reference == v]
		}
		
		def boolean variableReferenceIsInLoop(VariableDeclaration declaration, EObject context) {
			if(declaration.eContainer instanceof PackageAssociation) {
				return EcoreUtil2.getContainerOfType(context, Operation) !== null
					|| EcoreUtil2.getContainerOfType(context, EventHandlerDeclaration) !== null;
			}
			else {
				return EcoreUtil2.getContainerOfType(context, AbstractLoopStatement) !== null;
			}
		}
		
		dispatch def AbstractType doCreateConstraintsForMutating(InferenceContext c, VariableDeclaration variable, Set<Integer> variableSizes, AbstractType runningSize, AssignmentExpression expr) {
			val varRef = expr.varRef;			
			if(isOnLeftHandSide(variable, expr)) {
				val varRefContext = new InferenceContext(c, varRef);
				delegate.createConstraints(varRefContext);
				val result = c.system.newTypeVariable(variable);
				val resultTCT = typeVariableToTypeConstructorType(c, result, c.type as TypeConstructorType);
				val initSize = delegate.wrap(c, varRef, c.system.getTypeVariable(expr.expression));
				val runningSizeTCT = typeVariableToTypeConstructorType(c, runningSize, c.type as TypeConstructorType);
				val initSizeTCT = typeVariableToTypeConstructorType(c, initSize, c.type as TypeConstructorType);
				
				resultTCT.typeArguments.zip(runningSizeTCT.typeArguments.zip(initSizeTCT.typeArguments)).indexed
					.filter[variableSizes.contains(it.key)]
					.forEach[i___tr__t1_t2 | 
						val i = i___tr__t1_t2.key
						val tr__t1_t2 = i___tr__t1_t2.value
						// resultTCT is a new TCT with only type vars, see typeVariableToTypeConstructorType
						val tr = tr__t1_t2.key as TypeVariable;
						val t1_t2 = tr__t1_t2.value;
						val t1 = t1_t2.key;
						val t2 = t1_t2.value;
						if(expr.operator == AssignmentOperator.ADD_ASSIGN) {
							if(sizeTypeIndexes.contains(i)) {
								if(variableReferenceIsInLoop(variable, expr)) {
									c.system.addConstraint(new EqualityConstraint(c.system.newTypeVariable(expr.varRef), new BottomType(expr, '''Cannot infer sizes on append in loops'''), new ValidationIssue('''Cannot infer sizes on append in loops''', expr)))
								}
								else {
									c.system.addConstraint(new SumConstraint(tr, #[t1, t2], new ValidationIssue('''1''', expr)));
								}
							}
							else {
								c.system.addConstraint(new MaxConstraint(tr, #[t1, t2], new ValidationIssue('''2''', expr)))
							}
						}
						else if(expr.operator == AssignmentOperator.ASSIGN) {
							c.system.addConstraint(new MaxConstraint(tr, #[t1, t2], new ValidationIssue('''3''', expr)))
						}
					]

				return result;
				
			}
			else {
				return runningSize;	
			}
		}
				
		dispatch def AbstractType doCreateConstraintsForMutating(InferenceContext c, VariableDeclaration variable, Set<Integer> variableSizes, AbstractType runningSize, EObject object) {
			return createConstraintsForMutating(c, variable, variableSizes, object.eContents, runningSize);
		}
		
		
		override wrap(InferenceContext c, EObject obj, AbstractType inner) {
			return delegate.wrap(c, obj, inner);
		}
		
}