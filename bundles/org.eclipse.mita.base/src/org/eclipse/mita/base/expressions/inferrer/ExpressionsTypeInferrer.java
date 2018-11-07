/**
 * Copyright (c) 2014 committers of eclipse.mita and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 * Contributors:
 * 	committers of eclipse.mita - initial API and implementation
 * 
 */
package org.eclipse.mita.base.expressions.inferrer;

import static org.eclipse.mita.base.types.typesystem.ITypeSystem.ANY;
import static org.eclipse.mita.base.types.typesystem.ITypeSystem.BOOLEAN;
import static org.eclipse.mita.base.types.typesystem.ITypeSystem.INTEGER;
import static org.eclipse.mita.base.types.typesystem.ITypeSystem.NULL;
import static org.eclipse.mita.base.types.typesystem.ITypeSystem.REAL;
import static org.eclipse.mita.base.types.typesystem.ITypeSystem.STRING;
import static org.eclipse.mita.base.types.typesystem.ITypeSystem.VOID;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import org.eclipse.emf.common.util.EList;
import org.eclipse.xtext.EcoreUtil2;
import org.eclipse.mita.base.expressions.ArgumentExpression;
import org.eclipse.mita.base.expressions.AssignmentExpression;
import org.eclipse.mita.base.expressions.BitwiseAndExpression;
import org.eclipse.mita.base.expressions.BitwiseOrExpression;
import org.eclipse.mita.base.expressions.BitwiseXorExpression;
import org.eclipse.mita.base.expressions.BoolLiteral;
import org.eclipse.mita.base.expressions.ConditionalExpression;
import org.eclipse.mita.base.expressions.DoubleLiteral;
import org.eclipse.mita.base.expressions.ElementReferenceExpression;
import org.eclipse.mita.base.expressions.Expression;
import org.eclipse.mita.base.expressions.FeatureCall;
import org.eclipse.mita.base.expressions.FloatLiteral;
import org.eclipse.mita.base.expressions.HexLiteral;
import org.eclipse.mita.base.expressions.IntLiteral;
import org.eclipse.mita.base.expressions.LogicalAndExpression;
import org.eclipse.mita.base.expressions.LogicalNotExpression;
import org.eclipse.mita.base.expressions.LogicalOrExpression;
import org.eclipse.mita.base.expressions.LogicalRelationExpression;
import org.eclipse.mita.base.expressions.NullLiteral;
import org.eclipse.mita.base.expressions.NumericalAddSubtractExpression;
import org.eclipse.mita.base.expressions.NumericalMultiplyDivideExpression;
import org.eclipse.mita.base.expressions.NumericalUnaryExpression;
import org.eclipse.mita.base.expressions.ParenthesizedExpression;
import org.eclipse.mita.base.expressions.PostFixUnaryExpression;
import org.eclipse.mita.base.expressions.PrimitiveValueExpression;
import org.eclipse.mita.base.expressions.ShiftExpression;
import org.eclipse.mita.base.expressions.StringLiteral;
import org.eclipse.mita.base.expressions.TypeCastExpression;
import org.eclipse.mita.base.expressions.UnaryOperator;
import org.eclipse.mita.base.types.EnumerationType;
import org.eclipse.mita.base.types.Enumerator;
import org.eclipse.mita.base.types.GenericElement;
import org.eclipse.mita.base.types.Operation;
import org.eclipse.mita.base.types.Parameter;
import org.eclipse.mita.base.types.Property;
import org.eclipse.mita.base.types.Type;
import org.eclipse.mita.base.types.TypeAlias;
import org.eclipse.mita.base.types.TypeParameter;
import org.eclipse.mita.base.types.TypeSpecifier;
import org.eclipse.mita.base.types.inferrer.AbstractTypeSystemInferrer;
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor;

import com.google.common.collect.Maps;
import com.google.inject.Inject;

/**
 * @author andreas muelder - Initial contribution and API
 * 
 */
public class ExpressionsTypeInferrer extends AbstractTypeSystemInferrer implements ExpressionsTypeInferrerMessages {
	@Inject
	protected TypeParameterInferrer typeParameterInferrer;

	public InferenceResult doInfer(AssignmentExpression e) {
		InferenceResult result1 = inferTypeDispatch(e.getVarRef());
		InferenceResult result2 = inferTypeDispatch(e.getExpression());
		assertAssignable(result1, result2, String.format(ASSIGNMENT_OPERATOR, e.getOperator(), result1, result2));
		return inferTypeDispatch(e.getVarRef());
	}

	public InferenceResult doInfer(ConditionalExpression e) {
		InferenceResult result1 = inferTypeDispatch(e.getTrueCase());
		InferenceResult result2 = inferTypeDispatch(e.getFalseCase());
		assertCompatible(result1, result2, String.format(COMMON_TYPE, result1, result2));
		assertIsSubType(inferTypeDispatch(e.getCondition()), getResultFor(BOOLEAN), CONDITIONAL_BOOLEAN);
		return getCommonType(result1, result2);
	}

	public InferenceResult doInfer(LogicalOrExpression e) {
		InferenceResult result1 = inferTypeDispatch(e.getLeftOperand());
		InferenceResult result2 = inferTypeDispatch(e.getRightOperand());
		assertIsSubType(result1, getResultFor(BOOLEAN), String.format(LOGICAL_OPERATORS, "||", result1, result2));
		assertIsSubType(result2, getResultFor(BOOLEAN), String.format(LOGICAL_OPERATORS, "||", result1, result2));
		return getResultFor(BOOLEAN);
	}

	public InferenceResult doInfer(LogicalAndExpression e) {
		InferenceResult result1 = inferTypeDispatch(e.getLeftOperand());
		InferenceResult result2 = inferTypeDispatch(e.getRightOperand());
		assertIsSubType(result1, getResultFor(BOOLEAN), String.format(LOGICAL_OPERATORS, "&&", result1, result2));
		assertIsSubType(result2, getResultFor(BOOLEAN), String.format(LOGICAL_OPERATORS, "&&", result1, result2));
		return getResultFor(BOOLEAN);
	}

	public InferenceResult doInfer(LogicalNotExpression e) {
		InferenceResult type = inferTypeDispatch(e.getOperand());
		assertIsSubType(type, getResultFor(BOOLEAN), String.format(LOGICAL_OPERATOR, "!", type));
		return getResultFor(BOOLEAN);
	}

	public InferenceResult doInfer(BitwiseXorExpression e) {
		InferenceResult result1 = inferTypeDispatch(e.getLeftOperand());
		InferenceResult result2 = inferTypeDispatch(e.getRightOperand());
		assertIsSubType(result1, getResultFor(INTEGER), String.format(BITWISE_OPERATORS, "^", result1, result2));
		assertIsSubType(result2, getResultFor(INTEGER), String.format(BITWISE_OPERATORS, "^", result1, result2));
		return getResultFor(INTEGER);
	}

	public InferenceResult doInfer(BitwiseOrExpression e) {
		InferenceResult result1 = inferTypeDispatch(e.getLeftOperand());
		InferenceResult result2 = inferTypeDispatch(e.getRightOperand());
		assertIsSubType(result1, getResultFor(INTEGER), String.format(BITWISE_OPERATORS, "|", result1, result2));
		assertIsSubType(result2, getResultFor(INTEGER), String.format(BITWISE_OPERATORS, "|", result1, result2));
		return getResultFor(INTEGER);
	}

	public InferenceResult doInfer(BitwiseAndExpression e) {
		InferenceResult result1 = inferTypeDispatch(e.getLeftOperand());
		InferenceResult result2 = inferTypeDispatch(e.getRightOperand());
		assertIsSubType(result1, getResultFor(INTEGER), String.format(BITWISE_OPERATORS, "&", result1, result2));
		assertIsSubType(result2, getResultFor(INTEGER), String.format(BITWISE_OPERATORS, "&", result1, result2));
		return getResultFor(INTEGER);
	}

	public InferenceResult doInfer(ShiftExpression e) {
		InferenceResult result1 = inferTypeDispatch(e.getLeftOperand());
		InferenceResult result2 = inferTypeDispatch(e.getRightOperand());
		assertIsSubType(result1, getResultFor(INTEGER),
				String.format(BITWISE_OPERATORS, e.getOperator(), result1, result2));
		assertIsSubType(result2, getResultFor(INTEGER),
				String.format(BITWISE_OPERATORS, e.getOperator(), result1, result2));
		return getResultFor(INTEGER);
	}

	public InferenceResult doInfer(LogicalRelationExpression e) {
		InferenceResult result1 = inferTypeDispatch(e.getLeftOperand());
		InferenceResult result2 = inferTypeDispatch(e.getRightOperand());
		assertCompatible(result1, result2, String.format(COMPARSION_OPERATOR, e.getOperator(), result1, result2));
		InferenceResult result = getResultFor(BOOLEAN);
		return result;
	}

	public InferenceResult doInfer(NumericalAddSubtractExpression e) {
		InferenceResult result1 = inferTypeDispatch(e.getLeftOperand());
		InferenceResult result2 = inferTypeDispatch(e.getRightOperand());
		assertCompatible(result1, result2, String.format(ARITHMETIC_OPERATORS, e.getOperator(), result1, result2));
		assertIsSubType(result1, getResultFor(REAL),
				String.format(ARITHMETIC_OPERATORS, e.getOperator(), result1, result2));
		return getCommonType(inferTypeDispatch(e.getLeftOperand()), inferTypeDispatch(e.getRightOperand()));
	}

	public InferenceResult doInfer(NumericalMultiplyDivideExpression e) {
		InferenceResult result1 = inferTypeDispatch(e.getLeftOperand());
		InferenceResult result2 = inferTypeDispatch(e.getRightOperand());
		assertCompatible(result1, result2, String.format(ARITHMETIC_OPERATORS, e.getOperator(), result1, result2));
		assertIsSubType(result1, getResultFor(REAL),
				String.format(ARITHMETIC_OPERATORS, e.getOperator(), result1, result2));
		return getCommonType(result1, result2);
	}

	public InferenceResult doInfer(NumericalUnaryExpression e) {
		InferenceResult result1 = inferTypeDispatch(e.getOperand());
		if (e.getOperator() == UnaryOperator.COMPLEMENT)
			assertIsSubType(result1, getResultFor(INTEGER), String.format(BITWISE_OPERATOR, '~', result1));
		else {
			assertIsSubType(result1, getResultFor(REAL), String.format(ARITHMETIC_OPERATOR, e.getOperator(), result1));
		}
		return result1;
	}

	public InferenceResult doInfer(PostFixUnaryExpression e) {
		InferenceResult result = inferTypeDispatch(e.getOperand());
		assertIsSubType(result, getResultFor(REAL), String.format(POSTFIX_OPERATOR, e.getOperator(), result));
		return result;
	}

	public InferenceResult doInfer(TypeCastExpression e) {
		InferenceResult result1 = inferTypeDispatch(e.getOperand());
		InferenceResult result2 = inferTypeDispatch(e.getType());
		assertCompatible(result1, result2, String.format(CAST_OPERATORS, result1, result2));
		return inferTypeDispatch(e.getType());
	}

	public InferenceResult doInfer(EnumerationType enumType) {
		return InferenceResult.from(enumType);
	}

	public InferenceResult doInfer(Enumerator enumerator) {
		return InferenceResult.from(EcoreUtil2.getContainerOfType(enumerator, Type.class));
	}

	public InferenceResult doInfer(Type type) {
		return InferenceResult.from(type.getOriginType());
	}

	/**
	 * The type of a type alias is its (recursively inferred) base type, i.e. type
	 * aliases are assignable if their inferred base types are assignable.
	 */
	public InferenceResult doInfer(TypeAlias typeAlias) {
		return inferTypeDispatch(typeAlias.getTypeSpecifier());
	}

	public InferenceResult doInfer(FeatureCall e) {
		// map to hold inference results for type parameters
		Map<TypeParameter, InferenceResult> inferredTypeParameterTypes = Maps.newHashMap();
		typeParameterInferrer.inferTypeParametersFromOwner(inferTypeDispatch(e.getOwner()), inferredTypeParameterTypes);

		if (e.isOperationCall()) {
			if (!e.getFeature().eIsProxy()) {
				return inferOperation(e, (Operation) e.getFeature(), inferredTypeParameterTypes);
			} else {
				return getAnyType();
			}
		}
		InferenceResult result = inferTypeDispatch(e.getFeature());
		if (result != null) {
			result = typeParameterInferrer.buildInferenceResult(result, inferredTypeParameterTypes, acceptor);
		}
		if (result == null) {
			return getAnyType();
		}
		return result;
	}

	public InferenceResult doInfer(ElementReferenceExpression e) {
		if (e.isOperationCall()) {
			if (e.getReference() != null && !e.getReference().eIsProxy()) {
				if(e.getReference() instanceof Operation) {
					return inferOperation(e, (Operation) e.getReference(),
							Maps.<TypeParameter, InferenceResult>newHashMap());
				}
				else {
					return inferTypeDispatch(e.getReference());
				}
			} else {
				return getAnyType();
			}
		}
		return inferTypeDispatch(e.getReference());
	}

	protected InferenceResult inferOperation(ArgumentExpression e, Operation op,
			Map<TypeParameter, InferenceResult> typeParameterMapping) {
		// resolve type parameter from operation call
		List<InferenceResult> argumentTypes = getArgumentTypes(getOperationArguments(e));
		List<Parameter> parameters = op.getParameters();

		List<InferenceResult> argumentsToInfer = new ArrayList<>();
		List<Parameter> parametersToInfer = new ArrayList<>();

		for (int i = 0; i < parameters.size(); i++) {
			if (!typeParameterMapping.containsKey(parameters.get(i).getType())) {
				parametersToInfer.add(parameters.get(i));
				if (i < argumentTypes.size()) {
					argumentsToInfer.add(argumentTypes.get(i));
				}

			}
		}

		typeParameterInferrer.inferTypeParametersFromOperationArguments(parametersToInfer, argumentsToInfer,
				typeParameterMapping, acceptor);
		validateParameters(typeParameterMapping, op, getOperationArguments(e), acceptor);
		return inferReturnType(op, typeParameterMapping);
	}

	/**
	 * Can be extended to e.g. add operation caller to argument list for extension
	 * methods
	 */
	protected List<Expression> getOperationArguments(ArgumentExpression e) {
		return e.getExpressions();
	}

	protected List<InferenceResult> getArgumentTypes(List<Expression> args) {
		List<InferenceResult> argumentTypes = new ArrayList<>();
		for (Expression arg : args) {
			argumentTypes.add(inferTypeDispatch(arg));
		}
		return argumentTypes;
	}

	protected InferenceResult inferReturnType(Operation operation,
			Map<TypeParameter, InferenceResult> inferredTypeParameterTypes) {
		InferenceResult returnType = inferTypeDispatch(operation);
		returnType = typeParameterInferrer.buildInferenceResult(returnType, inferredTypeParameterTypes, acceptor);
		if (returnType == null) {
			return getAnyType();
		}
		return returnType;
	}

	private InferenceResult getAnyType() {
		return InferenceResult.from(registry.getType(ANY));
	}

	/**
	 * Takes the operation parameter type and performs a lookup for all contained
	 * type parameters by using the given type parameter inference map.<br>
	 * The parameter types are validated against the operation call's argument
	 * types.
	 * 
	 * @throws TypeParameterInferrenceException
	 */
	public Map<TypeParameter, InferenceResult> validateParameters(
			Map<TypeParameter, InferenceResult> typeParameterMapping, Operation operation, List<Expression> args,
			IValidationIssueAcceptor acceptor) {
		List<Parameter> parameters = operation.getParameters();
		for (int i = 0; i < parameters.size(); i++) {
			if (args.size() > i) {
				Parameter parameter = parameters.get(i);
				Expression argument = args.get(i);
				InferenceResult parameterType = inferTypeDispatch(parameter);
				InferenceResult argumentType = inferTypeDispatch(argument);
				parameterType = typeParameterInferrer.buildInferenceResult(parameterType, typeParameterMapping,
						acceptor);
				assertAssignable(parameterType, argumentType,
						String.format(INCOMPATIBLE_TYPES, argumentType, parameterType));
			}
		}
		return typeParameterMapping;
	}

	public InferenceResult doInfer(ParenthesizedExpression e) {
		return inferTypeDispatch(e.getExpression());
	}

	public InferenceResult doInfer(PrimitiveValueExpression e) {
		return inferTypeDispatch(e.getValue());
	}

	public InferenceResult doInfer(BoolLiteral literal) {
		return getResultFor(BOOLEAN);
	}

	public InferenceResult doInfer(IntLiteral literal) {
		return getResultFor(INTEGER);
	}

	public InferenceResult doInfer(HexLiteral literal) {
		return getResultFor(INTEGER);
	}

	public InferenceResult doInfer(DoubleLiteral literal) {
		return getResultFor(REAL);
	}

	public InferenceResult doInfer(FloatLiteral literal) {
		return getResultFor(REAL);
	}

	public InferenceResult doInfer(StringLiteral literal) {
		return getResultFor(STRING);
	}

	public InferenceResult doInfer(NullLiteral literal) {
		return getResultFor(NULL);
	}

	public InferenceResult doInfer(Property p) {
		InferenceResult type = inferTypeDispatch(p.getTypeSpecifier());
		return type;
	}

	public InferenceResult doInfer(Operation e) {
		return e.getTypeSpecifier() == null ? getResultFor(VOID) : inferTypeDispatch(e.getTypeSpecifier());
	}

	public InferenceResult doInfer(Parameter e) {
		return inferTypeDispatch(e.getTypeSpecifier());
	}

	public InferenceResult doInfer(TypeSpecifier specifier) {
		if (specifier.getType() instanceof GenericElement
				&& ((GenericElement) specifier.getType()).getTypeParameters().size() > 0) {
			List<InferenceResult> bindings = new ArrayList<>();
			EList<TypeSpecifier> arguments = specifier.getTypeArguments();
			for (TypeSpecifier typeSpecifier : arguments) {
				InferenceResult binding = inferTypeDispatch(typeSpecifier);
				if (binding != null) {
					bindings.add(binding);
				}
			}
			Type type = inferTypeDispatch(specifier.getType()).getType();
			return InferenceResult.from(type, bindings);
		}
		return inferTypeDispatch(specifier.getType());
	}
}
