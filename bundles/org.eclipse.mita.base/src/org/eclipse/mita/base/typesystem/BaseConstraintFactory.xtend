package org.eclipse.mita.base.typesystem

import com.google.inject.Inject
import com.google.inject.Provider
import java.util.ArrayList
import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
import org.eclipse.mita.base.expressions.AdditiveOperator
import org.eclipse.mita.base.expressions.ArrayAccessExpression
import org.eclipse.mita.base.expressions.BinaryExpression
import org.eclipse.mita.base.expressions.BoolLiteral
import org.eclipse.mita.base.expressions.ConditionalExpression
import org.eclipse.mita.base.expressions.DoubleLiteral
import org.eclipse.mita.base.expressions.ExpressionsPackage
import org.eclipse.mita.base.expressions.FloatLiteral
import org.eclipse.mita.base.expressions.IntLiteral
import org.eclipse.mita.base.expressions.LogicalOperator
import org.eclipse.mita.base.expressions.MultiplicativeOperator
import org.eclipse.mita.base.expressions.NumericalAddSubtractExpression
import org.eclipse.mita.base.expressions.NumericalMultiplyDivideExpression
import org.eclipse.mita.base.expressions.NumericalUnaryExpression
import org.eclipse.mita.base.expressions.PrimitiveValueExpression
import org.eclipse.mita.base.expressions.RelationalOperator
import org.eclipse.mita.base.expressions.StringLiteral
import org.eclipse.mita.base.expressions.TypeCastExpression
import org.eclipse.mita.base.expressions.UnaryOperator
import org.eclipse.mita.base.expressions.ValueRange
import org.eclipse.mita.base.types.AnonymousProductType
import org.eclipse.mita.base.types.ExceptionTypeDeclaration
import org.eclipse.mita.base.types.Expression
import org.eclipse.mita.base.types.GeneratedType
import org.eclipse.mita.base.types.NativeType
import org.eclipse.mita.base.types.NullTypeSpecifier
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.Parameter
import org.eclipse.mita.base.types.ParameterWithDefaultValue
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
import org.eclipse.mita.base.types.TypesUtil
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint
import org.eclipse.mita.base.typesystem.constraints.ExplicitInstanceConstraint
import org.eclipse.mita.base.typesystem.constraints.FunctionTypeClassConstraint
import org.eclipse.mita.base.typesystem.constraints.JavaClassInstanceConstraint
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.infra.TypeVariableProxy
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.BaseKind
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.IntegerType
import org.eclipse.mita.base.typesystem.types.NumericType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.Signedness
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeScheme
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.xtext.diagnostics.Severity
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.xtext.scoping.IScopeProvider

import static extension org.eclipse.mita.base.util.BaseUtils.force

class BaseConstraintFactory implements IConstraintFactory {
	
	@Inject
	protected IQualifiedNameProvider nameProvider;
	
	@Inject
	protected Provider<ConstraintSystem> constraintSystemProvider;
		
	@Inject 
	protected StdlibTypeRegistry typeRegistry;
	
	@Inject
	protected IScopeProvider scopeProvider;
	
	protected boolean isLinking;
	
	override ConstraintSystem create(EObject context) {		
		val result = constraintSystemProvider.get();
		result.computeConstraints(context);
		return result;
	}
	
	override setIsLinking(boolean isLinking) {
		this.isLinking = isLinking;
	}
	override getTypeRegistry() {
		return typeRegistry;
	}
	
	protected def TypeVariable resolveReferenceToSingleAndGetType(ConstraintSystem system, EObject origin, EReference featureToResolve) {
		if(isLinking) {
			return system.getTypeVariableProxy(origin, featureToResolve);
		}
		val obj = resolveReferenceToSingleAndLink(origin, featureToResolve);
		return system.getTypeVariable(obj);
	}
	
	protected def List<TypeVariable> resolveReferenceToTypes(ConstraintSystem system, EObject origin, EReference featureToResolve) {
		if(isLinking) {
			return #[system.getTypeVariableProxy(origin, featureToResolve)];
		}
		else {
			return resolveReference(origin, featureToResolve).map[system.getTypeVariable(it)].force;
		}
	}
	
	protected def List<EObject> resolveReference(EObject origin, EReference featureToResolve) {
		val scope = scopeProvider.getScope(origin, featureToResolve);
		
		val name = NodeModelUtils.findNodesForFeature(origin, featureToResolve).head?.text;
		if(name === null) {
			return #[];//system.associate(new BottomType(origin, "Reference text is null"));
		}
		
		if(origin.eIsSet(featureToResolve)) {
			return #[origin.eGet(featureToResolve, false) as EObject];	
		}
		
		val candidates = scope.getElements(QualifiedName.create(name.split("\\.")));
		
		val List<EObject> resultObjects = candidates.map[it.EObjectOrProxy].force;
		
		if(resultObjects.size === 1) {
			val candidate = resultObjects.head;
			if(candidate.eIsProxy) {
				println("!PROXY!")
			}
			BaseUtils.ignoreChange(origin, [
				origin.eSet(featureToResolve, candidate);	
			]);
		}
		
		return resultObjects;
	}
	
	
	
	protected def EObject resolveReferenceToSingleAndLink(EObject origin, EReference featureToResolve) {
		val candidates = resolveReference(origin, featureToResolve);
		val result = candidates.last;
		if(result !== null && origin.eGet(featureToResolve) === null) {
			origin.eSet(featureToResolve, result);
		}
		return result;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, EObject context) {
		println('''BCF: computeConstraints is not implemented for «context.eClass.name»''');
		system.computeConstraintsForChildren(context);
		return system.getTypeVariable(context);
	}
	
	protected def void computeConstraintsForChildren(ConstraintSystem system, EObject context) {
		context.eContents.forEach[ system.computeConstraints(it) ]
	}

	protected def computeParameterType(ConstraintSystem system, Operation function, Iterable<Parameter> parms) {
		val parmTypes = parms.map[system.computeConstraints(it)].filterNull.map[it as AbstractType].force();
		return new ProdType(null, new AtomicType(function, function.name + "_args"), parmTypes);
	}
	
	protected def AbstractType computeArgumentConstraints(ConstraintSystem system, String functionName, Iterable<Expression> expression) {
		val argTypes = expression.map[system.computeConstraints(it) as AbstractType].force();
		return system.computeArgumentConstraintsWithTypes(functionName, argTypes);
	}
	protected def AbstractType computeArgumentConstraintsWithTypes(ConstraintSystem system, String functionName, Iterable<AbstractType> argTypes) {
		return new ProdType(null, new AtomicType(null, functionName + "_args"), argTypes);
	}
	
	protected def TypeVariable computeConstraintsForFunctionCall(ConstraintSystem system, EObject functionCall, EReference functionReference, String functionName, Iterable<Expression> argExprs, List<TypeVariable> candidates) {
		return computeConstraintsForFunctionCall(system, functionCall, functionReference, functionName, system.computeArgumentConstraints(functionName, argExprs), candidates);
	}
	protected def TypeVariable computeConstraintsForFunctionCall(ConstraintSystem system, EObject functionCall, EReference functionReference, String functionName, AbstractType argumentType, List<TypeVariable> candidates) {
		if(candidates === null || candidates.empty) {
			return null;
		}
		val issue = new ValidationIssue(Severity.ERROR, '''Function «functionName» cannot be used here: %s, %s''', functionCall, functionReference, "");
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
		 * - assert a <= A
		 * - assert f(x): B
		 * - if f ∈ {f_1, f_2, ...}: (can only happen if isLinking == false!)
		 *   - compute {A_1, A_2 | f_i: A_i -> B_i}
		 *   - create TypeClass T for {A_1 -> B_1, ...}
		 *   - on resolve of T with function f_k: A_k -> B_k:
		 *     - we already know that A = A_k
		 *     - set the reference and assert relation of B_k and B with regards to their variance
		 * - otherwise f = f_1: A_1 -> B_1
		 * 	 - assert A -> B super type of A_1 -> B_1 (with indirection to prevent duplicate work, taking variance into account)
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
		val fromTV = system.newTypeVariable(null);
		// B
		val toTV = system.newTypeVariable(null);
		// A -> B
		val refType = new FunctionType(null, new AtomicType(null, functionName + "_call"), fromTV, toTV);
		// a
		val argType = argumentType
		// b
		val resultType = system.newTypeVariable(null);
		// a -> b
		val referencedFunctionType = new FunctionType(null, new AtomicType(null, functionName), argType, resultType);
		// a -> B >: A -> B
		system.addConstraint(new SubtypeConstraint(fromTV, argType, issue));
		val varianceOfResultVar = TypesUtil.getVarianceInAssignment(functionCall);
		switch(varianceOfResultVar) {
			case Covariant: {
				system.addConstraint(new SubtypeConstraint(resultType, toTV, issue));
			}
			case Contravariant: {
				system.addConstraint(new SubtypeConstraint(toTV, resultType, issue));
			}
			case Invariant: {
				system.addConstraint(new EqualityConstraint(toTV, resultType, issue));
			}
			
		}
		
		val useTypeClassProxy = !candidates.filter(TypeVariableProxy).empty
		val typeClassQN = QualifiedName.create(functionName);
		val typeClass = if(useTypeClassProxy) {
			if(candidates.size != 1) {
				// If we have a type class we are in the linking phase. 
				// This means that the caller called resolveToXX, which returned a proxy. 
				// However this should always create only one proxy.
				// Otherwise some candidates are resolved and some aren't, 
				// and we just don't know how this happened or how to handle it.
				// Basically safe .head
				throw new Exception("BCF: Somethings wrong!");
			}
			// this function call has the side effect of creating the type class.
			system.getTypeClassProxy(typeClassQN, candidates.head as TypeVariableProxy);
		}
		else {
			// this function call has the side effect of creating the type class.
			system.getTypeClass(typeClassQN, candidates.map[it as AbstractType -> it.origin]) => [ typeClass |	
			// add all candidates this TC doesn't already contain
				candidates.reject[typeClass.instances.containsKey(it)].force.forEach[
					typeClass.instances.put(it, it.origin);
				]	
			]
		}
		system.addConstraint(new FunctionTypeClassConstraint(issue, fromTV, typeClassQN, functionCall, functionReference, toTV, varianceOfResultVar, constraintSystemProvider));
		
		
		// B
		resultType;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ArrayAccessExpression expr) {
		// typing expr = a[idx]:
		// assert a :: array<t>
		// - get \T. array<T> (arrayType)
		// - type a[idx] :: t (innerType)
		// - make constraints to assert array<t> (nestInType)
		// compute typeof a (refType)
		// assert a = array<t>
		// recurse into accessor, computing idx :: s
		// assert idx is unsigned integer (s <= u32)
		// return t
		val arrayType = typeRegistry.getTypeModelObjectProxy(system, expr, StdlibTypeRegistry.arrayTypeQID);
		val innerType = system.getTypeVariable(expr);
		val supposedExpressionArrayType = nestInType(system, expr, innerType, arrayType, "array");
		
		val refType = system.computeConstraints(expr.owner);
		system.addConstraint(new EqualityConstraint(refType, supposedExpressionArrayType, new ValidationIssue(Severity.ERROR, '''«expr.owner» (:: %s) must be of type array<...>''', expr.owner)));
		val accessor = expr.arraySelector;
		val accessorType = system.computeConstraints(accessor);
		
		// here we could link to a builtin/generated function to facilitate easier code generation. For now just assert uintxx.
		val uint32Type = typeRegistry.getTypeModelObjectProxy(system, expr, StdlibTypeRegistry.u32TypeQID);
		system.addConstraint(new SubtypeConstraint(accessorType, uint32Type, new ValidationIssue(Severity.ERROR, '''«accessor» (:: %s) must be an unsigned integer''', accessor)));	
				
		return innerType;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ValueRange vr) {
		// assert that all values are unsigned integer (<= u32)
		// returns u32
		val uint32Type = typeRegistry.getTypeModelObjectProxy(system, vr, StdlibTypeRegistry.u32TypeQID);
		#[vr.lowerBound, vr.upperBound].filterNull.forEach[
			system.addConstraint(new SubtypeConstraint(system.computeConstraints(it), uint32Type, new ValidationIssue(Severity.ERROR, '''«it» (:: %s) must be an unsigned integer''', it)));
		]
		return system.associate(uint32Type, vr);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, TypeCastExpression expr) {
		// typing (expr as t)
		// compute expr :: s (realType)
		// get reference to t (castType)
		// validate that only numeric types are part of this cast (s and t must be numeric)
		// return t
		val realType = system.computeConstraints(expr.operand);
		val castType = system.resolveReferenceToSingleAndGetType(expr, ExpressionsPackage.eINSTANCE.typeCastExpression_Type);
		// only used in validation message
		val castTypeName = BaseUtils.getText(expr, ExpressionsPackage.eINSTANCE.typeCastExpression_Type);
		// can only cast from and to numeric types
		system.addConstraint(new JavaClassInstanceConstraint(
			new ValidationIssue(Severity.ERROR, '''«expr.operand» (:: %1$s) may not be cast''', expr, ExpressionsPackage.eINSTANCE.typeCastExpression_Operand, ""), 
			realType, NumericType
		));
		system.addConstraint(new JavaClassInstanceConstraint(
			new ValidationIssue(Severity.ERROR, '''May not cast to «castTypeName»''', expr, ExpressionsPackage.eINSTANCE.typeCastExpression_Type, ""), 
			castType, NumericType
		));
		return system.associate(castType, expr);
	}

	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, NumericalAddSubtractExpression expr) {
		val opQID = switch(expr.operator) {
			case(AdditiveOperator.PLUS): StdlibTypeRegistry.plusFunctionQID
			case(AdditiveOperator.MINUS): StdlibTypeRegistry.minusFunctionQID
		}
		return computeConstraintsForBuiltinOperation(system, expr, opQID, #[expr.leftOperand, expr.rightOperand]);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, NumericalMultiplyDivideExpression expr) {
		val opQID = switch(expr.operator) {
			case(MultiplicativeOperator.MUL): StdlibTypeRegistry.timesFunctionQID
			case(MultiplicativeOperator.DIV): StdlibTypeRegistry.divisionFunctionQID
			case(MultiplicativeOperator.MOD): StdlibTypeRegistry.moduloFunctionQID
		}
		return computeConstraintsForBuiltinOperation(system, expr, opQID, #[expr.leftOperand, expr.rightOperand]);
	}
	
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ParameterWithDefaultValue param) {
		// do base case of normal parameters and assert that the default value can be assigned to the parameter
		val paramType = system._computeConstraints(param as Parameter);
		if(param.defaultValue !== null) {
			val valueType = system.computeConstraints(param.defaultValue);
			system.addConstraint(new SubtypeConstraint(valueType, paramType, 
				new ValidationIssue(Severity.ERROR, '''Invalid default value «param.defaultValue» (:: %s) for parameter «param.name» (:: s)''', param.defaultValue, null, "")
			))
		}
		return paramType;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, BoolLiteral bl) {
		val boolType = typeRegistry.getTypeModelObjectProxy(system, bl, StdlibTypeRegistry.boolTypeQID);
		return system.associate(boolType, bl);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ConditionalExpression expr) {
		// typing (true ? a : b)
		val boolType = typeRegistry.getTypeModelObjectProxy(system, expr, StdlibTypeRegistry.boolTypeQID);
		system.addConstraint(new EqualityConstraint(system.computeConstraints(expr.condition), boolType, 
			new ValidationIssue(Severity.ERROR, '''«expr.condition» must be a boolean expression''', expr.condition, null, "")));
		// true and false  case/expression  must be share some common type
		val commonTV = system.getTypeVariable(expr);
		val trueTV = system.computeConstraints(expr.trueCase);
		var falseTV = system.computeConstraints(expr.falseCase);
		val mkIssue = [String f1, String f2, Expression e | new ValidationIssue(Severity.ERROR, '''«expr.trueCase»«f1» and «expr.falseCase»«f2» don't share a common type''', e, null, "")];
		system.addConstraint(new SubtypeConstraint(trueTV, commonTV, mkIssue.apply(" (:: %s)", "", expr.trueCase)));
		system.addConstraint(new SubtypeConstraint(falseTV, commonTV, mkIssue.apply("", " (:: %s)", expr.falseCase)));		
		return system.associate(commonTV);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, BinaryExpression expr) {
		if(expr.operator instanceof LogicalOperator) {
			val boolType = typeRegistry.getTypeModelObjectProxy(system, expr, StdlibTypeRegistry.boolTypeQID);
			val mkIssue = [new ValidationIssue(Severity.ERROR, '''«it» (:: %s) must be of type %s''', it, null, "")];
			system.addConstraint(new EqualityConstraint(system.computeConstraints(expr.leftOperand), boolType, mkIssue.apply(expr.leftOperand)))
			system.addConstraint(new EqualityConstraint(system.computeConstraints(expr.rightOperand), boolType, mkIssue.apply(expr.leftOperand)))
			return system.associate(boolType, expr);
		}
		else if(expr.operator instanceof RelationalOperator) {
			val boolType = typeRegistry.getTypeModelObjectProxy(system, expr, StdlibTypeRegistry.boolTypeQID);
			if(expr.operator == RelationalOperator.EQUALS || expr.operator == RelationalOperator.NOT_EQUALS) {
				// left and right must be subtype of some common type
				val commonTV = system.newTypeVariable(null);
				val mkIssue = [String f1, String f2, Expression e | new ValidationIssue(Severity.ERROR, '''«expr.leftOperand»«f1» and «expr.rightOperand»«f2» don't share a common type''', e, null, "")];
				system.addConstraint(new SubtypeConstraint(system.computeConstraints(expr.leftOperand), commonTV, mkIssue.apply(" (:: %s)", "", expr.leftOperand)));
				system.addConstraint(new SubtypeConstraint(system.computeConstraints(expr.rightOperand), commonTV, mkIssue.apply("", " (:: %s)", expr.rightOperand)));		
			}
			else {
				val mkIssue = [new ValidationIssue(Severity.ERROR, '''«it» must be an integer type''', it, null, "")];
				system.addConstraint(new JavaClassInstanceConstraint(mkIssue.apply(expr.leftOperand), system.computeConstraints(expr.leftOperand), NumericType))
				system.addConstraint(new JavaClassInstanceConstraint(mkIssue.apply(expr.rightOperand), system.computeConstraints(expr.rightOperand), NumericType))
			}
			return system.associate(boolType, expr);
		}
		else {
			return system.associate(new BottomType(expr, println("BinaryExpression not implemented for " + expr.operator)));
		}
	}
	
	protected def TypeVariable computeConstraintsForBuiltinOperation(ConstraintSystem system, EObject expr, QualifiedName opQID, List<Expression> operands) {
		val operations = typeRegistry.getModelObjects(system, expr, opQID, ExpressionsPackage.eINSTANCE.elementReferenceExpression_Reference);
		
		val resultType = system.computeConstraintsForFunctionCall(expr, null, opQID.lastSegment, operands, operations);
		return system.associate(resultType, expr);
	}

	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, Type type) {
		system.associate(system.translateTypeDeclaration(type), type);
	}

	protected def AbstractType translateTypeDeclaration(ConstraintSystem system, EObject obj) {
		val typeTrans = system.doTranslateTypeDeclaration(obj);
		system.associate(typeTrans, obj);
		if(obj instanceof Type) {
			if(obj.typeKind !== null) {
				system.computeConstraints(obj.typeKind);
			}
		}
		return typeTrans;
	}

	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, NativeType type) {
		return typeRegistry.translateNativeType(type);
	}
	
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, PrimitiveType type) {
		new AtomicType(type);
	}

	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, TypeParameter type) {
		return system.getTypeVariable(type);
	}
	
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, StructureType structType) {
		val types = structType.accessorsTypes.map[ system.computeConstraints(it) as AbstractType ].force();
		system.computeConstraints(structType.constructor);
		/*
		 * struct foo { var x: i32; var y: i32 }
		 * ---------------
		 * ProdType(foo, <>, [i32, i32])
		 */
		return new ProdType(structType, new AtomicType(structType), types);
	}
	
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, org.eclipse.mita.base.types.SumType sumType) {
		val subTypes = sumType.alternatives.map[ sumAlt |
			system.translateTypeDeclaration(sumAlt);
		].force;
		return new SumType(sumType, new AtomicType(sumType), subTypes);	
	}
	
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, SumAlternative sumAlt) {
		val selfType = new AtomicType(sumAlt);
		val types = sumAlt.accessorsTypes.map[ system.computeConstraints(it) as AbstractType ].force();
		val prodType = new ProdType(sumAlt, selfType, types);

		val superType = new AtomicType(sumAlt.eContainer, (sumAlt.eContainer as org.eclipse.mita.base.types.SumType).name);

		val iSelf_iSuper = system.explicitSubtypeRelations.addEdge(selfType, superType);
		system.explicitSubtypeRelationsTypeSource.put(iSelf_iSuper.key, prodType);
		system.explicitSubtypeRelationsTypeSource.put(iSelf_iSuper.value, system.getTypeVariable(sumAlt.eContainer));

		system.computeConstraints(sumAlt.constructor);

		return prodType;
	}
	
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, GeneratedType genType) {
		val typeParameters = genType.typeParameters;
		val typeArgs = typeParameters.map[
			system.computeConstraints(it)
		].force;

		system.computeConstraints(genType.constructor);			
		return if(typeParameters.empty) {
			new AtomicType(genType, genType.name);
		}
		else {
			new TypeScheme(genType, typeArgs, new TypeConstructorType(genType, new AtomicType(genType), typeArgs.map[it as AbstractType].force));
		}
	}
	
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, ExceptionTypeDeclaration genType) {
		return new AtomicType(genType);
	}
	
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, TypeKind context) {
		return new BaseKind(context, context.kindOf.name, system.getTypeVariable(context.kindOf));
	}
	
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, EObject genType) {
		println('''BCF: No doTranslateTypeDeclaration for «genType.eClass»''');
		return new AtomicType(genType, genType.toString);
	}
	
	protected def TypeConstructorType nestInType(ConstraintSystem system, EObject origin, AbstractType inner, AbstractType outerTypeScheme, String outerName) {
		return system.nestInType(origin, #[inner], outerTypeScheme, outerName);
	}
	protected def TypeConstructorType nestInType(ConstraintSystem system, EObject origin, Iterable<AbstractType> inner, AbstractType outerTypeScheme, String outerName) {
		// given reference to/typevariable \T. c<T>, t and nameof c:
		// constructs constraints asserting that c<t> instance of \T. c<T> and returns c<t>
		val outerTypeInstance = system.newTypeVariable(null);
		val nestedType = new TypeConstructorType(origin, new AtomicType(origin, outerName), inner.force);
		system.addConstraint(new ExplicitInstanceConstraint(outerTypeInstance, outerTypeScheme, new ValidationIssue(Severity.ERROR, '''«origin» (:: %s) is not instance of %s''', origin, null, "")));
		system.addConstraint(new EqualityConstraint(nestedType, outerTypeInstance, new ValidationIssue(Severity.ERROR, '''«origin» (:: %s) is not instance of %s''', origin, null, "")));
		return nestedType;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, PresentTypeSpecifier typeSpecifier) {
		// this is  t<a, b>  in  var x: t<a,  b>
		val typeArguments = typeSpecifier.typeArguments;
		
		// t
		val type = system.resolveReferenceToSingleAndGetType(typeSpecifier, TypesPackage.eINSTANCE.presentTypeSpecifier_Type);
		val typeWithoutModifiers = if(typeArguments.empty) {
			type;
		}
		else {
			// this type specifier is an instance of type
			// compute <a, b>
			val typeArgs = typeArguments.map[system.computeConstraints(it) as AbstractType].force;
			val typeName = typeSpecifier.type?.name ?: NodeModelUtils.findNodesForFeature(typeSpecifier, TypesPackage.eINSTANCE.presentTypeSpecifier_Type)?.head?.text?.trim;
			// compute constraints to validate t<a, b> (argument count etc.)
			val typeInstance = system.nestInType(null, typeArgs, type, typeName);
			typeInstance;
		}
		
		// handle reference modifiers (a: &t)
		val referenceTypeVarOrigin = typeRegistry.getTypeModelObjectProxy(system, typeSpecifier, StdlibTypeRegistry.referenceTypeQID);
		val typeWithReferenceModifiers = typeSpecifier.referenceModifiers.flatMap[it.split("").toList].fold(typeWithoutModifiers, [t, __ | 
			nestInType(system, null, t, referenceTypeVarOrigin, "reference");
		])
		
		//handle optional modifier (a: t?)
		val optionalTypeVarOrigin = typeRegistry.getTypeModelObjectProxy(system, typeSpecifier, StdlibTypeRegistry.optionalTypeQID);
		val typeWithOptionalModifier = if(typeSpecifier.optional) {
			nestInType(system, null, typeWithReferenceModifiers, optionalTypeVarOrigin, "optional");
		}
		else {
			typeWithReferenceModifiers;
		}
		
		return system.associate(typeWithOptionalModifier, typeSpecifier);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, TypedElement element) {
		return system.associate(system.computeConstraints(element.typeSpecifier), element);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, PrimitiveValueExpression t) {
		return system.associate(system.computeConstraints(t.value), t);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, NumericalUnaryExpression expr) {
		// this is the only way to handle negative int literals. 
		// It also is only a best guess, i.e. you can construct expressions with negative literal values that are types as u8.
		val operand = expr.operand;
		if(operand instanceof PrimitiveValueExpression) {
			val value = operand.value;
			if(value instanceof IntLiteral) {
				if(expr.operator == UnaryOperator.NEGATIVE) {
					val type = computeConstraints(system, operand, -value.value);
					system.associate(type, value);
					system.associate(type, operand);
					return system.associate(computeConstraints(system, operand, -value.value), expr);
				}
				println('''BCF: Unhandled operator: «expr.operator»''')	
			}
		}
		println('''BCF: Unhandled operand: «operand?.eClass.name»''')
		return system.associate(system.computeConstraints(operand), expr);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, IntLiteral lit) {
		return system.associate(system.computeConstraints(lit, lit.value), lit);
	}
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, FloatLiteral lit) {
		return system.associate(typeRegistry.getTypeModelObjectProxy(system, lit, StdlibTypeRegistry.floatTypeQID), lit);
	}
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, DoubleLiteral lit) {
		return system.associate(typeRegistry.getTypeModelObjectProxy(system, lit, StdlibTypeRegistry.doubleTypeQID), lit);
	}
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, StringLiteral lit) {
		return system.associate(typeRegistry.getTypeModelObjectProxy(system, lit, StdlibTypeRegistry.stringTypeQID), lit);
	}
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, StructuralParameter sParam) {
		/*
		 * in  struct foo { var x: i32; }
		 * this computes  var x: i32;
		 */
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
		return system.getTypeVariable(context);
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
		
		val typeVar = system.getTypeVariable(typeVarOrigin);
		if(typeVar != t && t !== null) { 
			system.addConstraint(new EqualityConstraint(typeVar, t, new ValidationIssue(Severity.ERROR, '''«typeVarOrigin» must be of type "%2$s"''', typeVarOrigin, null, "")));
		}
		return typeVar;	
	}
	
	
}