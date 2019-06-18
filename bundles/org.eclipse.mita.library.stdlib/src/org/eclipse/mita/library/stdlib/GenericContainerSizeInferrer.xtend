package org.eclipse.mita.library.stdlib

import com.google.inject.Inject
import java.util.ArrayList
import java.util.Collections
import java.util.List
import java.util.function.BiFunction
import java.util.function.Function
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.expressions.IntLiteral
import org.eclipse.mita.base.expressions.PrimitiveValueExpression
import org.eclipse.mita.base.types.NaryTypeAddition
import org.eclipse.mita.base.types.TypeExpressionSpecifier
import org.eclipse.mita.base.types.TypeReferenceSpecifier
import org.eclipse.mita.base.types.Variance
import org.eclipse.mita.base.typesystem.StdlibTypeRegistry
import org.eclipse.mita.base.typesystem.infra.ElementSizeInferrer
import org.eclipse.mita.base.typesystem.infra.InferenceContext
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.LiteralNumberType
import org.eclipse.mita.base.typesystem.types.NumericAddType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.program.inferrer.ProgramSizeInferrer
import org.eclipse.xtend.lib.annotations.Accessors

import static extension org.eclipse.mita.base.util.BaseUtils.force
import static extension org.eclipse.mita.base.util.BaseUtils.zip
import static extension org.eclipse.mita.base.util.BaseUtils.transpose
import org.eclipse.mita.base.typesystem.constraints.MaxConstraint
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.program.VariableDeclaration

/**
 * Automatic unbinding of size types and recursion of data types.
 * Can only handle TypeConstructorTypes.
 * createConstraints dispatches on InferenceContext.obj, and .type,
 * create doCreateConstraints(InferenceContext c, ? extends EObject obj, ? extends AbstractType t) to implement.
 */
abstract class GenericContainerSizeInferrer implements ElementSizeInferrer {
	@Accessors
	ElementSizeInferrer delegate;
	@Inject
	StdlibTypeRegistry typeRegistry
	
	/**
	 * return indexes specifying which type arguments of appropriate TypeConstructorTypes are data and which are size.
	 * remember that the first argument of TCTs are atomic types that just reference the constructor.
	 */
	def Iterable<Integer> getDataTypeIndexes();
	def Iterable<Integer> getSizeTypeIndexes();
		
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
		
		val sizeTypeIndexes = sizeTypeIndexes.force;
		val dataTypeIndexes = dataTypeIndexes.force;
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
		val sizeTypeIndexes = sizeTypeIndexes.force;
		val dataTypeIndexes = dataTypeIndexes.force;
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
	
//	dispatch def void doCreateConstraints(InferenceContext c, VariableDeclaration variable, TypeConstructorType type) {
//		if(!variable.writeable) {
//			delegate.createConstraints(c);
//		}
//		/*
//		 * Find initial size
//		 */
//		val variableRoot = EcoreUtil2.getContainerOfType(variable, Program);
//		val referencesToVariable = UsageCrossReferencer.find(variable, variableRoot).map[e | e.EObject ];
//		val varTypeSpec = variable.typeSpecifier;
//		val shouldHaveFixedSize = if(varTypeSpec instanceof TypeReferenceSpecifier) {
//			val lastTypeArg = varTypeSpec.typeArguments.last;
//			lastTypeArg instanceof TypeExpressionSpecifier;
//		}
//		val fixedSize = getSize(BaseUtils.getType(c.system, c.sub, variable.typeSpecifier))
//		if(fixedSize.present) {
//			replaceLastTypeArgument(c.sub, type, new LiteralNumberType(variable, fixedSize.get, type.typeArguments.last))
//		}
//		else if(shouldHaveFixedSize) {
//			return Optional.of(c);
//		}
//		
//		val initialization = variable.initialization ?: (
//			referencesToVariable
//				.map[it.eContainer]
//				.filter(AssignmentExpression)
//				.filter[ae |
//					val left = ae.varRef; 
//					left instanceof ElementReferenceExpression && (left as ElementReferenceExpression).reference === variable 
//				]
//				.map[it.expression]
//				.head
//		)
//		
//		var arrayHasFixedSize = false;
//		val initialType = if(initialization !== null) {
//			BaseUtils.getType(c.system, c.sub, initialization);
//		}
//		val initialLength = if(initialization !== null) {
//			getSize(initialType)
//		} 
//		else {
//			Optional.absent();
//		}
//		if(!initialLength.present) {
//			return Optional.of(c);
//		}
//		var typeArg = getDataType(initialType);
//		var length = initialLength.get;
//
//		/*
//		 * Strategy is to find all places where this variable is modified and try to infer the length there.
//		 */		
//		val modifyingExpressions = referencesToVariable.map[ref | 
//			val refContainer = ref.eContainer;
//			
//			if(refContainer instanceof AssignmentExpression) {
//				if(refContainer.varRef == ref) {
//					// we're actually assigning to this reference, thus modifying it
//					refContainer					
//				} else {
//					// the variable reference is just on the right side. No modification happening
//					null
//				}
//			} else {
//				null
//			}
//		]
//		.filterNull;
//		
//		/*
//		 * Check if we can infer the length across all modifications
//		 */
//		for(expr : modifyingExpressions) {
//			/*
//			 * First, let's see if we can infer the array length after the modification.
//			 */
//			var allowedInLoop = arrayHasFixedSize;
//			if(expr instanceof AssignmentExpression) {
//				val exprType = BaseUtils.getType(c.system, c.sub, expr.expression);
//				val biggerTypeArg = getDataType(exprType);
//				val mbLargerType = delegate.max(c.system, c.r, variable, #[typeArg, biggerTypeArg]);
//				if(mbLargerType.present) {
//					typeArg = mbLargerType.get
//				}
//				else {
//					// try again later, couldn't get max
//					return Optional.of(c);
//				}
//				
//				if(expr.operator == AssignmentOperator.ADD_ASSIGN) {
//					val additionLength = getSize(exprType);
//					// try again later
//					if(!additionLength.present) return Optional.of(c);
//					
//					length = length + additionLength.get;
//				} else if(expr.operator == AssignmentOperator.ASSIGN) {
//					val additionLength = getSize(BaseUtils.getType(c.system, c.sub, expr.expression));
//					// try again later
//					if(!additionLength.present) return Optional.of(c);
//					
//					allowedInLoop = true;
//					length = Math.max(length, additionLength.get);
//				} else {
//					// can't infer the length due to unknown operator
//					replaceLastTypeArgument(c.sub, type, new BottomType(expr, '''Cannot infer size when using the «expr.operator.getName()» operator'''));
//				}
//			}
//			
//			/*
//			 * Second, see if the modification happens in a loop. In that case we don't bother with trying to infer the length.
//			 * Because of block scoping we just have to find a loop container of the modifyingExpression and then make sure that
//			 * the loop container and the variable definition are/share a common ancestor.
//			 */
//			if(!allowedInLoop) {
//				val loopContainer = expr.getSharedLoopContainer(variable);
//				if(loopContainer !== null) {
//					replaceLastTypeArgument(c.sub, type, new BottomType(expr, '''Cannot infer «type.name» length in loops'''));
//				}	
//			}
//		}
//		
//		replaceLastTypeArgument(c.sub, type, new LiteralNumberType(variable, length, type.typeArguments.last));
//	}
}