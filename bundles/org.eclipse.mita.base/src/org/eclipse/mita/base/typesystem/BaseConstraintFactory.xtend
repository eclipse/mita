package org.eclipse.mita.base.typesystem

import com.google.inject.Inject
import com.google.inject.Provider
import java.util.ArrayList
import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
import org.eclipse.mita.base.expressions.AdditiveOperator
import org.eclipse.mita.base.expressions.DoubleLiteral
import org.eclipse.mita.base.expressions.Expression
import org.eclipse.mita.base.expressions.ExpressionsPackage
import org.eclipse.mita.base.expressions.FloatLiteral
import org.eclipse.mita.base.expressions.IntLiteral
import org.eclipse.mita.base.expressions.NumericalAddSubtractExpression
import org.eclipse.mita.base.expressions.NumericalUnaryExpression
import org.eclipse.mita.base.expressions.PrimitiveValueExpression
import org.eclipse.mita.base.expressions.StringLiteral
import org.eclipse.mita.base.expressions.TypeCastExpression
import org.eclipse.mita.base.expressions.UnaryOperator
import org.eclipse.mita.base.types.ComplexType
import org.eclipse.mita.base.types.ExceptionTypeDeclaration
import org.eclipse.mita.base.types.GeneratedType
import org.eclipse.mita.base.types.NativeType
import org.eclipse.mita.base.types.NullTypeSpecifier
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.Parameter
import org.eclipse.mita.base.types.PresentTypeSpecifier
import org.eclipse.mita.base.types.PrimitiveType
import org.eclipse.mita.base.types.StructuralParameter
import org.eclipse.mita.base.types.StructureType
import org.eclipse.mita.base.types.SumAlternative
import org.eclipse.mita.base.types.Type
import org.eclipse.mita.base.types.TypeKind
import org.eclipse.mita.base.types.TypeParameter
import org.eclipse.mita.base.types.TypedElement
import org.eclipse.mita.base.types.TypesPackage
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.constraints.TypeClassConstraint
import org.eclipse.mita.base.typesystem.infra.TypeTranslationAdapter
import org.eclipse.mita.base.typesystem.infra.TypeVariableAdapter
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.SimplificationResult
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.BaseKind
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.IntegerType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.Signedness
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeScheme
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.util.PreventRecursion
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.scoping.IScopeProvider

import static extension org.eclipse.mita.base.util.BaseUtils.force
import org.eclipse.mita.base.typesystem.constraints.FunctionTypeClassConstraint

class BaseConstraintFactory implements IConstraintFactory {
	
	@Inject
	protected IQualifiedNameProvider nameProvider;
	
	@Inject
	protected Provider<ConstraintSystem> constraintSystemProvider;
		
	@Inject 
	protected StdlibTypeRegistry typeRegistry;
	
	protected boolean isLinking;
	
	public override ConstraintSystem create(EObject context) {
		val result = constraintSystemProvider.get();
		result.computeConstraints(context);
		return result;
	}
	
	public override setIsLinking(boolean isLinking) {
		this.isLinking = isLinking;
	}
	override getTypeRegistry() {
		return typeRegistry;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, EObject context) {
		println('''BCF: computeConstraints is not implemented for «context.eClass.name»''');
		system.computeConstraintsForChildren(context);
		return TypeVariableAdapter.get(context);
	}
	
	protected def void computeConstraintsForChildren(ConstraintSystem system, EObject context) {
		context.eContents.forEach[ system.computeConstraints(it) ]
	}

	protected def computeParameterType(ConstraintSystem system, Operation function, Iterable<Parameter> parms) {
		val parmTypes = parms.map[system.computeConstraints(it)].filterNull.map[it as AbstractType].force();
		return new ProdType(null, function.name + "_args", parmTypes, #[]);
	}
	
	protected def AbstractType computeArgumentConstraints(ConstraintSystem system, String functionName, Iterable<Expression> expression) {
		val argTypes = expression.map[system.computeConstraints(it) as AbstractType].force();
		return new ProdType(null, functionName + "_args", argTypes, #[]);
	}
	
	protected def TypeVariable computeConstraintsForFunctionCall(ConstraintSystem system, EObject functionCall, EReference functionReference, String functionName, Iterable<Expression> argExprs, List<Operation> candidates) {
		if(candidates === null || candidates.empty) {
			return null;
		}
		/* This function is pretty complicated. It handles function calls like `f(x)` or `x.f()`.
		 * We get:
		 * - an object holding the function call, "f(x)"
		 * - a reference which will be set to the called function
		 * - the function's name "f"
		 * - the arguments of the call "[x]"
		 * - the possible candidates the function name could reference, {f_1, f_2, ...}
		 *   
		 * To compute type constraints of `f(x)` we do the following:
		 * - compute x: a
		 * - assert f: A -> B
		 * - assert A >: a
		 * - assert f(x): B
		 * - if f ∈ {f_1, f_2, ...}:
		 *   - compute {A_1, A_2 | f_i: A_i -> B_i}
		 *   - create TypeClass T for {A_1, ...}
		 *   - on resolve of T with function f_k: A_k -> B_k:
		 *     - we already know that A = A_k
		 *     - set the reference and assert B >: B_k 
		 * - otherwise f = f_1: A_1 -> B_1
		 * 	 - assert A -> B super type of A_1 -> B_1 (with indirection to prevent duplicate work)
		 * - return B (the type of this expression)
		 * 
		 * Now we know that:
		 * - f: A -> B
		 * - f = f_k
		 * - f_k: A_k -> B_k
		 * - A = A_k
		 * - B = B_k
		 */
		//Allocate TypeVariables for functionCall
		// A
		val fromTV = new TypeVariable(null);
		// B
		val toTV = new TypeVariable(null);
		// A -> B
		val refType = new FunctionType(null, functionName + "_call", fromTV, toTV);
		// a
		val argType = system.computeArgumentConstraints(functionName, argExprs);
		// b
		val resultType = new TypeVariable(null);
		// a -> b
		val referencedFunctionType = new FunctionType(null, functionName, argType, resultType);
		// a -> B >: A -> B
		system.addConstraint(new SubtypeConstraint(refType, referencedFunctionType));
		
		if(candidates.size > 1) {
			val tcQN = QualifiedName.create(functionName);
			//val candidateTypes = candidates.filter(Operation).map[system.computeParameterType(it, it.parameters) as AbstractType -> it as EObject];
			val candidateTypes = candidates.filter(Operation).map[TypeVariableAdapter.get(it) as AbstractType -> it as EObject];
			// this would be nicer since we can spare some computation, but since right now the type variables are bound to EObjects this is not possible.
			// we should probably replace this by some IdentityMap which keeps track of the types instead.
			//val candidateTypes = candidates.filter(Operation).map[TypeVariableAdapter.get(it.parameters) as AbstractType -> it as EObject];
			// this function call has the side effect of creating the type class.
			val typeClass = system.getTypeClass(QualifiedName.create(functionName), candidateTypes);
			// add all candidates this TC doesn't already contain
			candidateTypes.reject[typeClass.instances.containsKey(it)].force.forEach[
				typeClass.instances.put(it.key, it.value);
			]
			system.addConstraint(new FunctionTypeClassConstraint(referencedFunctionType, tcQN, functionCall, functionReference, toTV, constraintSystemProvider));
		}
		else {
			val funRef = candidates.head;
			if(functionReference !== null && functionCall.eGet(functionReference) === null) {
				functionCall.eSet(functionReference, funRef);	
			}
			// the actual function should be a subtype of the expected function so it can be used here
			system.addConstraint(new SubtypeConstraint(TypeVariableAdapter.get(funRef), refType));
		}
		// B
		resultType;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, TypeCastExpression expr) {
		val realType = system.computeConstraints(expr.operand);
		val castType = system.computeConstraints(expr.type);
		// can only cast from and to numeric types
		// TODO: check this with constraints, either one:
		// - subtype of common numerical type, or make u64 <: f64
		// - add constraint "instanceOf(t, NumericalType)" that checks if (in Java) `t instanceof NumericalType
		//	-> will only be checked once t contains no more free vars, like subtype constraints 
		return system.associate(castType, expr);
	}

	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, NumericalAddSubtractExpression expr) {
		if(isLinking) {
			return TypeVariableAdapter.getProxy(expr, ExpressionsPackage.eINSTANCE.elementReferenceExpression_Reference);
		}
		
		val opQID = if(expr.operator === AdditiveOperator.PLUS) {
			StdlibTypeRegistry.plusFunctionQID;
		} else {
			StdlibTypeRegistry.minusFunctionQID;
		}
		val plusOps = typeRegistry.getModelObjects(expr, opQID, ExpressionsPackage.eINSTANCE.elementReferenceExpression_Reference);
		val resultType = system.computeConstraintsForFunctionCall(expr, null, StdlibTypeRegistry.plusFunctionQID.lastSegment, #[expr.leftOperand, expr.rightOperand], plusOps.filter(Operation).force);
		return system.associate(resultType, expr);
	}

	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, Type type) {
		system.associate(system.translateTypeDeclaration(type), type);
	}

	protected def AbstractType translateTypeDeclaration(ConstraintSystem system, EObject obj) {
		// some types may have circular dependencies. 
		// To make it easy to solve this we cache type translations, reducing the required number of translations to O(1).
		// So if some translation needs to recurse it can safely do so, as long as at least one member in the recursive circle sets its type translation before recursing.
		val typeTrans = TypeTranslationAdapter.get(obj, [|system.doTranslateTypeDeclaration(obj)])
		// if we compile more than once without changes we need to associate again. Hence we always associate here to be safe.
		system.associate(typeTrans, obj);
		// for the same reason we need to iterate over all children of these types.
		// since some of these types might call computeConstrains on their eContainer we need to get out the big guns or have a translateForChildren dispatch method.
		PreventRecursion.preventRecursion(obj, [|system.computeConstraintsForChildren(obj); return null;]);
		return typeTrans;
	}

	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, NativeType type) {
		return typeRegistry.translateNativeType(type)
	}
	
	
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, PrimitiveType type) {
		new AtomicType(type, type.name);
	}

	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, TypeParameter type) {
		return TypeVariableAdapter.get(type);
	}
	
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, StructureType structType) {
		val types = structType.accessorsTypes.map[ system.computeConstraints(it) as AbstractType ].force();
		return TypeTranslationAdapter.set(structType, new ProdType(structType, structType.name, types, #[])) => [
			system.computeConstraints(structType.constructor);	
		];
	}
	
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, org.eclipse.mita.base.types.SumType sumType) {
		val subTypes = new ArrayList();
		return TypeTranslationAdapter.set(sumType, new SumType(sumType, sumType.name, subTypes, #[])) => [
			sumType.alternatives.forEach[ sumAlt |
				subTypes.add(system.translateTypeDeclaration(sumAlt));
			];
		]
	}
	 
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, SumAlternative sumAlt) {
		println(sumAlt);
		val types = sumAlt.accessorsTypes.map[ system.computeConstraints(it) as AbstractType ].force();
		val prodType = new ProdType(sumAlt, sumAlt.name, types, #[system.translateTypeDeclaration(sumAlt.eContainer)]);
		return TypeTranslationAdapter.set(sumAlt, prodType) => [
			system.computeConstraints(sumAlt.constructor);
		];
	}
		
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, GeneratedType genType) {
		val typeParameters = genType.typeParameters;
		val typeArgs = typeParameters.map[ system.computeConstraints(it) ].force();

		return TypeTranslationAdapter.set(genType, if(typeParameters.empty) {
			new AtomicType(genType, genType.name);
		}
		else {
			new TypeScheme(genType, typeArgs, new TypeConstructorType(genType, genType.name, typeArgs.map[it as AbstractType].force));
		}) => [
			system.computeConstraints(genType.constructor);			
		]
	}
	
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, ExceptionTypeDeclaration genType) {
		return new AtomicType(genType, genType.name);
	}
	
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, TypeKind context) {
		return new BaseKind(context, context.kindOf.name, TypeVariableAdapter.get(context.kindOf));
	}
	
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, EObject genType) {
		println('''BCF: No doTranslateTypeDeclaration for «genType.eClass»''');
		return new AtomicType(genType);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, PresentTypeSpecifier typeSpecifier) {
		if(isLinking) {
			return TypeVariableAdapter.getProxy(typeSpecifier, TypesPackage.eINSTANCE.presentTypeSpecifier_Type);
		}
		
		val typeArguments = typeSpecifier.typeArguments;
		if(typeSpecifier.type === null) {
			return system.associate(new BottomType(typeSpecifier, "BCF: Unresolved type"));
		}
		if(typeArguments.empty) {
			return system.associate(system.translateTypeDeclaration(typeSpecifier.type), typeSpecifier);
		}
		else {
			if(!(typeSpecifier.type instanceof ComplexType)) {
				return system.associate(new BottomType(typeSpecifier, "BCF: Specified type doesn't have type arguments"))
			}
			if(typeArguments.size !== (typeSpecifier.type as ComplexType).typeParameters.size) {
				return system.associate(new BottomType(typeSpecifier, "BCF: Specified and the type's type arguments differ in length"))
			}
			val vars_typeScheme = system.translateTypeDeclaration(typeSpecifier.type).instantiate();
			val vars = vars_typeScheme.key;
			for(var i = 0; i < Integer.min(typeArguments.size, vars.size); i++) {
				system.addConstraint(new EqualityConstraint(vars.get(i), system.computeConstraints(typeArguments.get(i)), "BCF:307"));
			}
			return system.associate(vars_typeScheme.value, typeSpecifier);
		}
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, TypedElement element) {
		return system.associate(system.computeConstraints(element.typeSpecifier), element);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, PrimitiveValueExpression t) {
		return system.associate(system.computeConstraints(t.value), t);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, NumericalUnaryExpression expr) {
		val operand = expr.operand;
		if(operand instanceof IntLiteral) {
			if(expr.operator == UnaryOperator.NEGATIVE) {
				return system.associate(computeConstraints(system, operand, -operand.value), expr);
			}
			println('''BCF: Unhandled operator: «expr.operator»''')
		}
		println('''BCF: Unhandled operand: «operand.eClass.name»''')
		return system.associate(system.computeConstraints(operand), expr);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, IntLiteral lit) {
		return system.associate(system.computeConstraints(lit, lit.value), lit);
	}
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, FloatLiteral lit) {
		return system.associate(typeRegistry.getFloatType(lit), lit);
	}
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, DoubleLiteral lit) {
		return system.associate(typeRegistry.getDoubleType(lit), lit);
	}
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, StringLiteral lit) {
		return system.associate(typeRegistry.getStringType(lit), lit);
	}
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, StructuralParameter sParam) {
		system.computeConstraints(sParam.accessor);
		return system._computeConstraints(sParam as TypedElement);
	}

	protected def TypeVariable computeConstraints(ConstraintSystem system, EObject source, long value) {
		val sign = if(value < 0) {
			Signedness.Signed;
		} else {
			if(value > 127 && value <= 255) {
				Signedness.Unsigned;
			}
			else if(value > 32767 && value <= 65535) {
				Signedness.Unsigned;
			}
			else if(value > 2147483647L && value <= 4294967295L) {
				Signedness.Unsigned;
			}
			else {
				Signedness.DontCare;
			}
		}
		val byteCount = 
			if(value >= 0 && value <= 255) {
				1;
			}
			else if(value > 255 && value <= 65535) {
				2;
			}
			else if(value > 65535 && value <= 4294967295L) {
				4;
			}
			else if(value >= -128 && value < 0) {
				1;
			} 
			else if(value >= -32768 && value < -128) {
				2;
			}
			else if(value >= -2147483648L && value < -32768) {
				4;
			}
			else {
				return system.associate(new BottomType(source, "BCF: Value out of bounds: " + value));
			}
		return system.associate(new IntegerType(source, byteCount, sign));
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, NullTypeSpecifier context) {
		return TypeVariableAdapter.get(context);
	}

	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, Void context) {
		println('BCF: computeConstraints called on null');
		return null;
	}

	protected def associate(ConstraintSystem system, AbstractType t) {
		return associate(system, t, t.origin);
	}
	
	protected def associate(ConstraintSystem system, AbstractType t, EObject typeVarOrigin) {
		if(typeVarOrigin === null) {
			throw new UnsupportedOperationException("BCF: Associating a type variable without origin is not supported (on purpose)!");
		}
		
		val typeVar = TypeVariableAdapter.get(typeVarOrigin);
		if(typeVar != t && t !== null) {
			system.addConstraint(new EqualityConstraint(typeVar, t, "BCF:412"));
		}
		return typeVar;	
	}
	
	
}