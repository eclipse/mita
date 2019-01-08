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
		val issue = new ValidationIssue(Severity.ERROR, '''Function «functionName» cannot be used here''', functionCall, functionReference, "");
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
		 *   - create TypeClass T for {A_1 -> B_1, ...}
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
		// this function call has the side effect of creating the type class.
		val typeClass = if(useTypeClassProxy) {
			if(candidates.size != 1) {
				throw new Exception("BCF: Somethings wrong!");
			}
			system.getTypeClassProxy(typeClassQN, candidates.head as TypeVariableProxy);
		}
		else {
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
		val uint32Type = typeRegistry.getTypeModelObjectProxy(system, vr, StdlibTypeRegistry.u32TypeQID);
		#[vr.lowerBound, vr.upperBound].filterNull.forEach[
			system.addConstraint(new SubtypeConstraint(system.computeConstraints(it), uint32Type, new ValidationIssue(Severity.ERROR, '''«it» (:: %s) must be an unsigned integer''', it)));
		]
		return system.associate(uint32Type, vr);
		
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, TypeCastExpression expr) {
		val realType = system.computeConstraints(expr.operand);
		val castType = system.resolveReferenceToSingleAndGetType(expr, ExpressionsPackage.eINSTANCE.typeCastExpression_Type);
		val castTypeName = BaseUtils.getText(expr, ExpressionsPackage.eINSTANCE.typeCastExpression_Type);
		// can only cast from and to numeric types
		system.addConstraint(new JavaClassInstanceConstraint(
			new ValidationIssue(Severity.ERROR, '''«expr.operand» (:: %1$s) may not be casted''', expr, ExpressionsPackage.eINSTANCE.typeCastExpression_Operand, ""), 
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
		val boolType = typeRegistry.getTypeModelObjectProxy(system, expr, StdlibTypeRegistry.boolTypeQID);
		system.addConstraint(new EqualityConstraint(system.computeConstraints(expr.condition), boolType, 
			new ValidationIssue(Severity.ERROR, '''«expr.condition» must be a boolean expression''', expr.condition, null, "")));
		// true and false case must be subtype of some common type
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
			system.addConstraint(new SubtypeConstraint(system.computeConstraints(expr.leftOperand), boolType, mkIssue.apply(expr.leftOperand)))
			system.addConstraint(new SubtypeConstraint(system.computeConstraints(expr.rightOperand), boolType, mkIssue.apply(expr.leftOperand)))
			return system.associate(boolType, expr);
		}
		else if(expr.operator instanceof RelationalOperator) {
			val boolType = typeRegistry.getTypeModelObjectProxy(system, expr, StdlibTypeRegistry.boolTypeQID);
			if(expr.operator == RelationalOperator.EQUALS || expr.operator == RelationalOperator.EQUALS) {
				// left and right must be subtype of some common type
				val commonTV = system.newTypeVariable(null);
				val mkIssue = [String f1, String f2, Expression e | new ValidationIssue(Severity.ERROR, '''«expr.leftOperand»«f1» and «expr.rightOperand»«f2» don't share a common type''', e, null, "")];
				system.addConstraint(new SubtypeConstraint(system.computeConstraints(expr.leftOperand), commonTV, mkIssue.apply(" (:: %s)", "", expr.leftOperand)));
				system.addConstraint(new SubtypeConstraint(system.computeConstraints(expr.rightOperand), commonTV, mkIssue.apply("", " (:: %s)", expr.rightOperand)));		
			}
			else {
				val x8type = typeRegistry.getTypeModelObjectProxy(system, expr, StdlibTypeRegistry.x8TypeQID);
				val mkIssue = [new ValidationIssue(Severity.ERROR, '''«it» must be an integer type''', it, null, "")];
				system.addConstraint(new SubtypeConstraint(x8type, system.computeConstraints(expr.leftOperand), mkIssue.apply(expr.leftOperand)))
				system.addConstraint(new SubtypeConstraint(x8type, system.computeConstraints(expr.rightOperand), mkIssue.apply(expr.rightOperand)))
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
		system.computeConstraintsForChildren(obj);
		// if we compile more than once without changes we need to associate again. Hence we always associate here to be safe.
		system.associate(typeTrans, obj);
		return typeTrans;
	}

	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, NativeType type) {
		return typeRegistry.translateNativeType(type)
	}
	
	
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, PrimitiveType type) {
		new AtomicType(type, type.name);
	}

	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, TypeParameter type) {
		return system.getTypeVariable(type);
	}
	
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, StructureType structType) {
		val types = structType.accessorsTypes.map[ system.computeConstraints(it) as AbstractType ].force();
		system.computeConstraints(structType.constructor);	
		return new ProdType(structType, new AtomicType(structType), types);
	}
	
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, org.eclipse.mita.base.types.SumType sumType) {
		val subTypes = new ArrayList();
		sumType.alternatives.forEach[ sumAlt |
			subTypes.add(system.translateTypeDeclaration(sumAlt));
		];
		return new SumType(sumType, new AtomicType(sumType), subTypes);
		
	}
	 
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, AnonymousProductType prodType) {
//		if(prodType.importingConstructor !== null) {
//			system.associate(null, prodType.importingConstructor);
//		}
		return system._doTranslateTypeDeclaration(prodType as SumAlternative);
	}
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, SumAlternative sumAlt) {
		val types = sumAlt.accessorsTypes.map[ system.computeConstraints(it) as AbstractType ].force();
		val prodType = new ProdType(sumAlt, new AtomicType(sumAlt), types);
		system.explicitSubtypeRelations.addEdge(prodType, system.getTypeVariable(sumAlt.eContainer));
		system.computeConstraints(sumAlt.constructor);
		return prodType;
	}
	
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, GeneratedType genType) {
		val typeParameters = genType.typeParameters;
		val typeArgs = typeParameters.map[ 
			system.computeConstraints(it)
		].force();

		system.computeConstraints(genType.constructor);			
		return if(typeParameters.empty) {
			new AtomicType(genType, genType.name);
		}
		else {
			new TypeScheme(genType, typeArgs, new TypeConstructorType(genType, new AtomicType(genType), typeArgs.map[it as AbstractType].force));
		}
	}
	
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, ExceptionTypeDeclaration genType) {
		return new AtomicType(genType, genType.name);
	}
	
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, TypeKind context) {
		return new BaseKind(context, context.kindOf.name, system.getTypeVariable(context.kindOf));
	}
	
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, EObject genType) {
		println('''BCF: No doTranslateTypeDeclaration for «genType.eClass»''');
		return new AtomicType(genType, genType.toString);
	}
	
	protected def TypeConstructorType nestInType(ConstraintSystem system, EObject origin, AbstractType inner, AbstractType outerTypeScheme, String outerName) {
		val outerTypeInstance = system.newTypeVariable(null);
		val nestedType = new TypeConstructorType(origin, new AtomicType(origin, outerName), #[inner]);
		if(origin === null) {
			print("")
		}
		system.addConstraint(new ExplicitInstanceConstraint(outerTypeInstance, outerTypeScheme, new ValidationIssue(Severity.ERROR, '''«origin» (:: %s) is not instance of %s''', origin, null, "")));
		system.addConstraint(new EqualityConstraint(nestedType, outerTypeInstance, new ValidationIssue(Severity.ERROR, '''«origin» (:: %s) is not instance of %s''', origin, null, "")));
		nestedType;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, PresentTypeSpecifier typeSpecifier) {	
		val typeArguments = typeSpecifier.typeArguments;
//		val type = if(typeSpecifier.type !== null) {
//			//system.translateTypeDeclaration(typeSpecifier.type)
//		} 
//		else {
//		}
		val type = system.resolveReferenceToSingleAndGetType(typeSpecifier, TypesPackage.eINSTANCE.presentTypeSpecifier_Type);
		val typeWithoutModifiers = if(typeArguments.empty) {
			type;
		}
		else {
			// this type specifier is an instance of type
			val typeArgs = typeArguments.map[system.computeConstraints(it) as AbstractType].force;
			val typeName = typeSpecifier.type?.name ?: NodeModelUtils.findNodesForFeature(typeSpecifier, TypesPackage.eINSTANCE.presentTypeSpecifier_Type)?.head?.text?.trim;
			val typeInstance = new TypeConstructorType(null, new AtomicType(null, typeName), typeArgs);
			val typeInstanceVar = system.newTypeVariable(null);
			system.addConstraint(new ExplicitInstanceConstraint(typeInstanceVar, type, new ValidationIssue(Severity.ERROR, '''«typeSpecifier» is not instance of %2$s''', typeSpecifier, null, "")));
			system.addConstraint(new EqualityConstraint(typeInstance, typeInstanceVar, new ValidationIssue(Severity.ERROR, '''«typeSpecifier» is not instance of %2$s''', typeSpecifier, null, "")));
			typeInstance;
		}
		
		val referenceTypeVarOrigin = typeRegistry.getTypeModelObjectProxy(system, typeSpecifier, StdlibTypeRegistry.referenceTypeQID);
		
		//val optionalType = typeRegistry.getOptionalType(system, typeSpecifier);
		val typeWithReferenceModifiers = typeSpecifier.referenceModifiers.flatMap[it.split("").toList].fold(typeWithoutModifiers, [t, __ | 
			nestInType(system, null, t, referenceTypeVarOrigin, "reference");
		])
		
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