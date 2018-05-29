/********************************************************************************
 * Copyright (c) 2017, 2018 Bosch Connected Devices and Solutions GmbH.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Bosch Connected Devices and Solutions GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

package org.eclipse.mita.program.inferrer

import com.google.common.collect.Maps
import com.google.inject.Inject
import java.util.List
import java.util.Map
import java.util.TreeMap
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.util.EcoreUtil.UsageCrossReferencer
import org.eclipse.mita.base.expressions.Argument
import org.eclipse.mita.base.expressions.ArgumentExpression
import org.eclipse.mita.base.expressions.AssignmentExpression
import org.eclipse.mita.base.expressions.BoolLiteral
import org.eclipse.mita.base.expressions.DoubleLiteral
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.Expression
import org.eclipse.mita.base.expressions.FeatureCall
import org.eclipse.mita.base.expressions.FloatLiteral
import org.eclipse.mita.base.expressions.IntLiteral
import org.eclipse.mita.base.expressions.inferrer.ExpressionsTypeInferrer
import org.eclipse.mita.base.scoping.MitaTypeSystem
import org.eclipse.mita.base.types.AnonymousProductType
import org.eclipse.mita.base.types.HasAccessors
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.Property
import org.eclipse.mita.base.types.StructureType
import org.eclipse.mita.base.types.SumAlternative
import org.eclipse.mita.base.types.SumType
import org.eclipse.mita.base.types.TypeParameter
import org.eclipse.mita.base.types.inferrer.ITypeSystemInferrer.InferenceResult
import org.eclipse.mita.base.types.typesystem.ITypeSystem
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ListBasedValidationIssueAcceptor
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue.Severity
import org.eclipse.mita.platform.Modality
import org.eclipse.mita.platform.SystemResourceAlias
import org.eclipse.mita.program.ArrayAccessExpression
import org.eclipse.mita.program.ArrayLiteral
import org.eclipse.mita.program.DereferenceExpression
import org.eclipse.mita.program.ForEachLoopIteratorVariableDeclaration
import org.eclipse.mita.program.ForEachStatement
import org.eclipse.mita.program.FunctionDefinition
import org.eclipse.mita.program.GeneratedFunctionDefinition
import org.eclipse.mita.program.InterpolatedStringExpression
import org.eclipse.mita.program.IsDeconstructionCase
import org.eclipse.mita.program.IsDeconstructor
import org.eclipse.mita.program.ModalityAccess
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.program.ProgramBlock
import org.eclipse.mita.program.ReferenceExpression
import org.eclipse.mita.program.ReturnStatement
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.ValueRange
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.mita.program.scoping.ExtensionMethodHelper
import org.eclipse.mita.program.validation.ProgramDslTypeValidator
import org.eclipse.xtext.EcoreUtil2

import static org.eclipse.mita.base.scoping.MitaTypeSystem.ARRAY_TYPE
import static org.eclipse.mita.base.scoping.MitaTypeSystem.BOOL_TYPE
import static org.eclipse.mita.base.scoping.MitaTypeSystem.DOUBLE_TYPE
import static org.eclipse.mita.base.scoping.MitaTypeSystem.FLOAT_TYPE
import static org.eclipse.mita.base.scoping.MitaTypeSystem.MODALITY_TYPE
import static org.eclipse.mita.base.scoping.MitaTypeSystem.REFERENCE_TYPE
import static org.eclipse.mita.base.scoping.MitaTypeSystem.INT32_TYPE
import static org.eclipse.mita.base.scoping.MitaTypeSystem.SIGINST_TYPE
import static org.eclipse.mita.base.types.typesystem.ITypeSystem.VOID

class ProgramDslTypeInferrer extends ExpressionsTypeInferrer {

	public static final String VARIABLE_DECLARATION = "Cannot assign a value of type %s to a variable of type %s.";

	public static final String NO_RETURN_TYPE_INFERRED = "Could not infer common return type from operation's return statements";

	public static final String DEREFERENCE_OF_NON_REFERENCE_MSG = "Can not dereference non-reference types.";
	public static final String DEREFERENCE_OF_NON_REFERENCE_CODE = "DEREFERENCE_OF_NON_REFERENCE_CODE";

	public static final String INTEGER_VALUE_OUT_OF_RANGE_MSG = "Value is out of range. Must be %d <= x <= %d.";
	public static final String INTEGER_VALUE_OUT_OF_RANGE_CODE = "value_out_of_range";

	public static final String INT_LITERAL_TYPE = INT32_TYPE;
	public static final String DOUBLE_LITERAL_TYPE = DOUBLE_TYPE;
	public static final String FLOAT_LITERAL_TYPE = FLOAT_TYPE;
	public static final String BOOL_LITERAL_TYPE = BOOL_TYPE;
	public static final String ARRAY_LITERAL_TYPE = ARRAY_TYPE;

	@Inject
	extension ExtensionMethodHelper
	
	@Inject 
	extension ProgramDslTypeValidator programDslTypeValidator

	override protected InferenceResult inferTypeDispatch(EObject object) {
		val result = super.inferTypeDispatch(object)
		// Map abstract base types to default Mita types
		if (result !== null && result.type.abstract) {
			return switch result.type {
				case registry.getType(ITypeSystem.REAL):
					return InferenceResult.from(registry.getType(DOUBLE_LITERAL_TYPE))
				case registry.getType(ITypeSystem.BOOLEAN):
					return InferenceResult.from(registry.getType(BOOL_LITERAL_TYPE))
				default:
					result
			}
		}
		return result;
	}

	override doInfer(DoubleLiteral literal) {
		return InferenceResult.from(registry.getType(DOUBLE_LITERAL_TYPE))
	}

	override doInfer(IntLiteral literal) {
		return InferenceResult.from(registry.getType(ITypeSystem.INTEGER))
	}

	override doInfer(FloatLiteral literal) {
		return InferenceResult.from(registry.getType(FLOAT_LITERAL_TYPE))
	}

	override doInfer(BoolLiteral literal) {
		return InferenceResult.from(registry.getType(BOOL_LITERAL_TYPE))
	}
	
	def doInfer(ArrayLiteral literal) {
		val outer = InferenceResult.from(registry.getType(ARRAY_LITERAL_TYPE));
		val inner = literal.values.head.inferTypeDispatch;
		outer.bindings += inner;
		return outer;
	}
		
	def doInfer(DereferenceExpression e) {
		val refType = e.expression.inferTypeDispatch;
		if (refType !== null && refType.bindings.length > 0) {
			return refType.bindings.head;
		} else {
			this.acceptor.accept(
				new ValidationIssue(Severity.ERROR, DEREFERENCE_OF_NON_REFERENCE_MSG, e,
					DEREFERENCE_OF_NON_REFERENCE_CODE));
			return null;
		}
	}

	def doInfer(ReferenceExpression e) {
		val innerType = e.variable.inferTypeDispatch;
		val outerType = getResultFor(REFERENCE_TYPE);
		outerType.bindings.add(innerType);
		return outerType;
	}

	def doInfer(SignalInstance e) {
		val explicitType = e.typeSpecifier?.inferTypeDispatch
		val originalItemType = e.instanceOf.inferTypeDispatch;

		val typeSpec = if (explicitType !== null) {
			assertNotType(explicitType, VARIABLE_VOID_TYPE, getResultFor(VOID));
			assertAssignable(explicitType, originalItemType,
				String.format(VARIABLE_DECLARATION, explicitType, originalItemType));
				
			explicitType;
		} else {
			originalItemType;
		}
		val siginstType = getResultFor(SIGINST_TYPE);
		siginstType.bindings.add(typeSpec);
		return siginstType;
	}

	def doInfer(NewInstanceExpression e) {
		return e.type.inferTypeDispatch;
	}

	def doInfer(Modality e) {
		val result = getResultFor(MODALITY_TYPE);
		result.bindings.add(e.typeSpecifier.inferTypeDispatch);
		return result;
	}
	
	def doInfer(ModalityAccess e) {
		return e?.modality?.typeSpecifier?.inferTypeDispatch;
	}

	def doInfer(AnonymousProductType typ) {
		if (typ.typeSpecifiers.length == 1) {
			return typ.typeSpecifiers.head.inferTypeDispatch;
		} else {
			return super.doInfer(typ);
		}
	}

	def doInfer(IsDeconstructor deconstructor) {
		var result = deconstructor.productMember.inferTypeDispatch;
		if (result === null) {
			val isCase = deconstructor.eContainer as IsDeconstructionCase;
			val rType = isCase.productType.realType;
			val types = if (rType instanceof HasAccessors) {
					rType.accessorsTypes;
				} else {
					#[rType];
				}
			var idx = isCase.deconstructors.indexOf(deconstructor);
			result = types.get(idx).inferTypeDispatch;
		}
		return result;
	}

	def doInfer(VariableDeclaration e) {
		var explicitType = e.typeSpecifier.inferTypeDispatch;
		assertNotType(explicitType, VARIABLE_VOID_TYPE, getResultFor(VOID));
		if (e.initialization === null)
			return explicitType;

		val implicitType = e.initialization.inferTypeDispatch;
		if (explicitType !== null) {
			// there is an explicit type specification, so make sure the initialization expression is type compatible
			assertAssignable(explicitType, implicitType, String.format(VARIABLE_DECLARATION, implicitType, explicitType));
			assertWithinRange(explicitType, e.initialization, e);
			return explicitType;
		} else {
			// there is no explicit type specification, so return the inferred type of the initialization expression
			return implicitType.replace(e);
		}
	}
	
	def InferenceResult replace(InferenceResult result, VariableDeclaration object) {
		if (registry.isSame(result?.type, registry.getType(ITypeSystem.INTEGER))) {
			return object.doInferIntegerByUse(result)
		} else if (result !== null && !result.bindings.empty) {
			return InferenceResult.from(result.type, result.bindings.map[it.replace(null)])
		}
		return result
	}

	def protected doInferIntegerByUse(VariableDeclaration declaration, InferenceResult original) {
		// Use this for common use
//		val usages = UsageCrossReferencer.find(declaration, declaration.eResource).map[EObject.inferByUsage]
//		val result = usages.reduce[registry.getCommonType($0, $1)]

		if (declaration !== null) {
			val firstUsage = UsageCrossReferencer.find(declaration, declaration.eResource).head?.EObject?.inferByUsage
			if (firstUsage !== null) {
				val issueAcceptor = new ListBasedValidationIssueAcceptor
				assertAssignable(firstUsage, original, "", issueAcceptor)
				if (issueAcceptor.traces.empty) {
					return firstUsage;
				}
			}
		}
		InferenceResult.from(registry.getType(INT_LITERAL_TYPE))
	}

	def protected dispatch InferenceResult inferByUsage(EObject reference) {
		InferenceResult.from(registry.getType(INT_LITERAL_TYPE))
	}

	def protected dispatch InferenceResult inferByUsage(ElementReferenceExpression reference) {
		var argument = EcoreUtil2.getContainerOfType(reference, Argument)
		if (argument !== null) {
			return argument.inferByUsage(reference)
		}
		var typedElement = EcoreUtil2.getContainerOfType(reference, Property)
		if (typedElement !== null) {
			return typedElement.inferTypeDispatch
		}
	}

	def protected InferenceResult inferByUsage(Argument argument, ElementReferenceExpression use) {
		return if (argument.parameter !== null)
			inferTypeDispatch(argument.parameter.type)
		else if (argument.eContainer instanceof ArgumentExpression) {
			val argumentExpression = argument.eContainer as ArgumentExpression
			var op = argumentExpression.operation;
			var index = argumentExpression.arguments.indexOf(argument)
			index += op.parameters.size - argumentExpression.arguments.size
			inferTypeDispatch(op.parameters.get(index).type)
		} else
			registry.getType(INT_LITERAL_TYPE).inferTypeDispatch
	}

	def dispatch operation(ArgumentExpression it) {}

	def dispatch operation(ElementReferenceExpression it) {
		reference as Operation
	}

	def dispatch operation(FeatureCall it) {
		feature as Operation
	}

	override protected inferOperation(ArgumentExpression e, Operation op, Map<TypeParameter, InferenceResult> typeParameterMapping) {
		// we need to compare by (not hashcode) here, since I can't seem to find the exact type parameter super. ... tries to look up.
		var Map<TypeParameter, InferenceResult> typeParameterMapping2 = new TreeMap([x, y | 
			x.name.compareTo(y.name)
		])
		typeParameterMapping2.putAll(typeParameterMapping);
		
		if(op instanceof GeneratedFunctionDefinition && op.parameters.empty) {
			var EObject parentDecl = EcoreUtil2.getContainerOfType(e, VariableDeclaration);
			if(parentDecl === null) {
				val retStmt = EcoreUtil2.getContainerOfType(e, ReturnStatement);
				if(retStmt !== null) {
					parentDecl = EcoreUtil2.getContainerOfType(retStmt, FunctionDefinition);
				}
			} 
			if(parentDecl === null) {
				val assignmentExpr = EcoreUtil2.getContainerOfType(e, AssignmentExpression);
				var varRef = assignmentExpr?.varRef;
				while(varRef instanceof ArrayAccessExpression) {
					varRef = varRef.owner;
				}
				while(varRef instanceof FeatureCall) {
					varRef = varRef.owner;
				}
				if(varRef instanceof ElementReferenceExpression) {
					parentDecl = varRef.reference;
				}
			} 
			
			val parentTypeSpec = if(parentDecl instanceof VariableDeclaration) {
				if(parentDecl !== null && parentDecl.typeSpecifier !== null) {
					parentDecl.typeSpecifier;
				}
			} else if(parentDecl instanceof FunctionDefinition) {
				ModelUtils.toSpecifier(parentDecl.inferTypeDispatch);
			}
			
			if(parentTypeSpec !== null && parentTypeSpec.type.name == op.type.name) {
				val finalMap = typeParameterMapping2
				op.typeParameters.indexed.forEach[idx_tp | 
					finalMap.put(idx_tp.value, parentTypeSpec.typeArguments.get(idx_tp.key).inferTypeDispatch);
				]
			}
		}
		if (e instanceof FeatureCall) {
			val ownerType = inferTypeDispatch(e.getOwner())
			if (op.isExtensionMethodOn(ownerType.type)) {
				return super.inferOperation(e, op, typeParameterMapping2.adjustForExtensionMethod(op))
			}
		}
		return super.inferOperation(e, op, typeParameterMapping2)
	}

	override validateParameters(Map<TypeParameter, InferenceResult> typeParameterMapping, Operation operation, List<Expression> args, IValidationIssueAcceptor acceptor) {
		val parameters = operation.getParameters();

		for (var parameter = 0; parameter < parameters.size(); parameter++) {
			if (args.size() > parameter) {
				val varArgs = parameters.get(parameter);
				val argType = this.inferTypeDispatch(varArgs);
				val parameterValue = args.get(parameter);
				
				assertWithinRange(argType, parameterValue, varArgs);
			}
		}
		
		super.validateParameters(typeParameterMapping, operation, args, acceptor)
	}
	
	protected def assertWithinRange(InferenceResult result, Expression expression, EObject target) {
		val staticValue = StaticValueInferrer.infer(expression, []);
		if(!(staticValue instanceof Integer)) {
			return;
		}
		val staticIntValue = staticValue as Integer;
		
		val ranges = #{
			'uint8' -> #[new Long(0), new Long(255)],
			'int8' -> #[new Long(-128), new Long(127)],
			'uint16' -> #[new Long(0), new Long(65535)],
			'int16' -> #[new Long(-32768), new Long(32767)],
			'uint32' -> #[new Long(0), new Long("4294967295")],
			'int32' -> #[new Long("-2147483648"), new Long("2147483647")]
		}
		val type = result?.type;
		val range = ranges.getOrDefault(type?.name, null);
		if(range !== null) {
			if(staticIntValue < range.get(0) || staticIntValue > range.get(1)) {
				val errorMessage = String.format(INTEGER_VALUE_OUT_OF_RANGE_MSG, range.get(0), range.get(1));
				acceptor.accept(new ValidationIssue(Severity.ERROR, errorMessage, target, INTEGER_VALUE_OUT_OF_RANGE_CODE));
			}
		}
	}

	def doInfer(ForEachLoopIteratorVariableDeclaration e) {
		val iterableExpr = (e.eContainer as ForEachStatement)?.iterable
		val iterableType = iterableExpr.inferTypeDispatch
		assertIsSubType(iterableType, InferenceResult.from(registry.getType(MitaTypeSystem.ITERABLE_TYPE)), null);
		val elementType = iterableType.bindings.head
		return elementType
	}

	def doInfer(InterpolatedStringExpression e) {
		getResultFor(ITypeSystem.STRING)
	}

	def doInfer(SystemResourceAlias e) {
		return InferenceResult.from(e.delegate)
	}
	
	override doInfer(FeatureCall fc) {
		if (fc.feature instanceof SumAlternative) {
			val owner = fc.owner;
			if(owner instanceof ElementReferenceExpression) {
				val ref = owner.reference;
				if(ref instanceof SumType) {
					return InferenceResult.from(ref);
				}
			}
		}
		else {
			return super.doInfer(fc);
		}
	}
	
	def doInfer(SystemResourceSetup e) {
		return e.type.inferTypeDispatch
	}

	def doInfer(ReturnStatement returnStatement) {
		return inferTypeDispatch(returnStatement.value);
	}

	override List<Expression> getOperationArguments(ArgumentExpression e) {
		if (e instanceof FeatureCall) {
			val operation = e.feature as Operation
			if (e.owner !== null && operation.isExtensionMethodOn(inferTypeDispatch(e.owner)?.type)) {
				return combine(e.owner, e.expressions);
			}
		}
		return e.expressions
	}

	def doInfer(FunctionDefinition operation) {
		if (operation.getTypeSpecifier() === null) {
			return inferTypeFromReturnStatements(operation.getBody());
		}
		return doInfer(operation.getTypeSpecifier());
	}

	def doInfer(ArrayAccessExpression e) {
		if(e.arraySelector instanceof ValueRange) {
			return e.owner.inferTypeDispatch;
		}
		else {
			return e.owner.inferTypeDispatch.bindings.head;
		}
	} 

	override doInfer(ElementReferenceExpression e) {
		if (e.isOperationCall()) {
			val ref = e.reference;
			if (ref instanceof StructureType) {
				return InferenceResult.from(ref);
			}
			else if(ref instanceof SumAlternative) {
				return InferenceResult.from(ref.eContainer as SumType);
			}
			return super.doInfer(e);
		}
		return super.doInfer(e)
	}

	protected def inferTypeFromReturnStatements(ProgramBlock body) {
		if (body.content.isEmpty()) {
			return getResultFor(VOID)
		}
		val returnStatements = EcoreUtil2.getAllContentsOfType(body, ReturnStatement);

		if (returnStatements.isEmpty()) {
			return getResultFor(VOID)
		}

		var returnType = doInfer(returnStatements.head);
		// infer common type of all return statements
		for (var i = 1; i < returnStatements.size(); i++) {
			val next = doInfer(returnStatements.get(i));
			returnType = getCommonReturnType(returnType, next);
			if (returnType === null) {
				return getResultFor(VOID);
			}
		}
		if (returnType !== null && returnType.type == registry.getType(ITypeSystem.INTEGER)) {
			return InferenceResult.from(registry.getType(INT_LITERAL_TYPE))
		}
		return returnType;
	}

	protected def InferenceResult getCommonReturnType(InferenceResult left, InferenceResult right) {
		assertCompatible(left, right, NO_RETURN_TYPE_INFERRED);
		val commonType = registry.getCommonType(left.getType(), right.getType());
		if (commonType === null) {
			return null;
		}
		return InferenceResult.from(commonType, left.getBindings());
	}

	/**
	 * When we call an extension method on a generic typed variable, this variable defines a type mapping from type parameters to concrete types.
	 * For example: "var x = new array<int16>(10);" maps the type parameter T of array<T> to int16.
	 * However, an extension method defines its own type parameters: "fn <S> myFun2(p : array<S>) {}".
	 * This method finds a mapping from T to S (callerTypeParamToOperationTypeParam) and from there derives the mapping S to int16.
	 */
	def adjustForExtensionMethod(Map<TypeParameter, InferenceResult> inferredTypeParameters, Operation operation) {
		val p = operation.parameters.head
		val pType = inferTypeDispatch(p)
		val callerTypeParamToOperationTypeParam = Maps.newHashMap();
		typeParameterInferrer.inferTypeParametersFromOwner(pType, callerTypeParamToOperationTypeParam);

		val adjustedTypeParameterMapping = Maps.newHashMap();
		inferredTypeParameters.forEach [ tp, t |
			if (callerTypeParamToOperationTypeParam.get(tp)?.type instanceof TypeParameter)
				// exchange type parameter in mapping
				adjustedTypeParameterMapping.put(callerTypeParamToOperationTypeParam.get(tp).type as TypeParameter, t)
			else
				// nothing to exchange
				adjustedTypeParameterMapping.put(tp, t)
		]
		return adjustedTypeParameterMapping
	}

}
