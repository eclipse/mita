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

package org.eclipse.mita.program.validation

import com.google.inject.Inject
import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.expressions.Argument
import org.eclipse.mita.base.expressions.ArgumentExpression
import org.eclipse.mita.base.expressions.AssignmentExpression
import org.eclipse.mita.base.expressions.AssignmentOperator
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.Expression
import org.eclipse.mita.base.expressions.ExpressionsPackage
import org.eclipse.mita.base.expressions.FeatureCall
import org.eclipse.mita.base.expressions.PrimitiveValueExpression
import org.eclipse.mita.base.expressions.inferrer.ExpressionsTypeInferrerMessages
import org.eclipse.mita.base.types.AnonymousProductType
import org.eclipse.mita.base.types.ComplexType
import org.eclipse.mita.base.types.GeneratedType
import org.eclipse.mita.base.types.NamedElement
import org.eclipse.mita.base.types.NamedProductType
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.Parameter
import org.eclipse.mita.base.types.Property
import org.eclipse.mita.base.types.StructureType
import org.eclipse.mita.base.types.SumType
import org.eclipse.mita.base.types.TypeSpecifier
import org.eclipse.mita.base.types.TypesPackage
import org.eclipse.mita.base.types.inferrer.ITypeSystemInferrer.InferenceResult
import org.eclipse.mita.base.types.typesystem.ITypeSystem
import org.eclipse.mita.base.types.validation.TypeValidator
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.platform.Modality
import org.eclipse.mita.program.ArrayAccessExpression
import org.eclipse.mita.program.ArrayLiteral
import org.eclipse.mita.program.DereferenceExpression
import org.eclipse.mita.program.DoWhileStatement
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.FunctionDefinition
import org.eclipse.mita.program.FunctionParameterDeclaration
import org.eclipse.mita.program.GeneratedFunctionDefinition
import org.eclipse.mita.program.IfStatement
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.ProgramBlock
import org.eclipse.mita.program.ProgramPackage
import org.eclipse.mita.program.ReturnStatement
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.ValueRange
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.WhileStatement
import org.eclipse.mita.program.inferrer.ElementSizeInferrer
import org.eclipse.mita.program.inferrer.InvalidElementSizeInferenceResult
import org.eclipse.mita.program.inferrer.ProgramDslTypeInferrer
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.inferrer.ValidElementSizeInferenceResult
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.mita.program.resource.PluginResourceLoader
import org.eclipse.mita.program.scoping.ExtensionMethodHelper
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.validation.Check
import org.eclipse.xtext.validation.CheckType
import org.eclipse.xtext.validation.ComposedChecks

import static org.eclipse.mita.base.types.typesystem.ITypeSystem.VOID

@ComposedChecks(validators = #[
	ProgramNamesAreUniqueValidator,
	ProgramImportValidator,
	ProgramSetupValidator,
	SumTypesValidator,
	ReferenceTypesValidator
])
class ProgramDslValidator extends AbstractProgramDslValidator {

	public static val WRONG_NR_OF_ARGS_CODE = "wrong_nr_of_args";
	public static val WRONG_NR_OF_ARGS_MSG = "Wrong number of arguments, expected %s."

	public static val MIXED_PARAMS_CODE = "mixed_parameter"
	public static val MIXED_PARAMS_MSG = "Positional and named parameters must not be mixed."

	public static val MISSING_CONNECTIVITY_CODE = 'missing_connectivity'

	public static val String VOID_OP_CANNOT_RETURN_VALUE_MSG = "Void operations cannot return a value.";
	public static val String VOID_OP_CANNOT_RETURN_VALUE_CODE = "void_op_cannot_return_value";
	
	public static final String VOID_VARIABLE_TYPE = "Void is an invalid type for variables";

	public static val String MISSING_RETURN_VALUE_MSG = "The operation must return a value of type %s.";
	public static val String MISSING_RETURN_VALUE_CODE = "missing_return_value";

	public static val String INCOMPATIBLE_RETURN_TYPE_MSG = "The return type '%s' is not compatible with the operation's type '%s'.";
	public static val String INCOMPATIBLE_RETURN_TYPE_CODE = "incompatible_return_type";
	
	public static val String FUNCTION_RETURN_TYPE_NOT_PRIMITIVE_MSG = "Returning non-primitive values from functions is experimental and might result in invalid C code.";
	public static val String FUNCTION_RETURN_TYPE_NOT_PRIMITIVE_CODE = "function_return_type_not_primitive"

	public static val String EVENT_RETURNS_VALUE_MSG = "Events may not return values.";
	public static val String EVENT_RETURNS_VALUE_CODE = "event_return_value_not_nothing";

	public static val String VARIABLE_NOT_UNIQUE_MSG = "Cannot redeclare variable '%s'.";
	public static val String VARIABLE_NOT_UNIQUE_CODE = "variable_not_unique";

	public static val String NO_PLATFORM_SELECTED_MSG = "No platform selected. Please import one of the available platforms: \"%s.\"";
	public static val String NO_PLATFORM_SELECTED_CODE = "no_platform_selected";
	
	public static val String FUNCTIONS_CAN_NOT_BE_REFERENCED_MSG = "Functions can not be used as values. Please add parentheses.";
	public static val String FUNCTIONS_CAN_NOT_BE_REFERENCED_CODE = "no_function_references";
	
	public static val String OPTIONAL_PARAMETERS_NOT_IMPLEMENTED_MSG = "Default values for function parameters are not allowed.";
	public static val String OPTIONAL_PARAMETERS_NOT_IMPLEMENTED_CODE = "optional_parameters_not_implemented";
	
	public static val String INCOMPATIBLE_TYPES_MSG = "Incompatible types: '%s' can't be converted to '%s'."
	
	public static val String ARRAY_LITERALS_CANT_BE_EMPTY = "Array literals can not be empty.";
	
	public static val String ARRAY_LITERAL_IS_NOT_HOMOGENOUS = "Array literal is not homogenous.";
	
	public static val String ARRAY_RANGE_INVALID = "Array range is invalid: %s";
	public static val String ARRAY_RANGE_ONLY_ON_ARRAY = "Array ranges are only supported on array types.";
	
	public static val String NESTED_ARRAY_LITERALS_NOT_SUPPORTED = "Nested array literals are not supported yet.";
	public static val String ARRAY_SLICES_ARE_NOT_SUPPORTED_TOP_LEVEL = "Array slices are not supported in global scope.";
	
	public static val String ARRAY_INDEX_OUT_OF_BOUNDS = "Array index out of bounds: length = %d";
	
	public static val String ARRAY_INDEX_MUST_BE_INTEGER = "Array index must be integer.";
	
	public static val String NESTED_GENERATED_TYPES_ARE_NOT_SUPPORTED = "Nested generated types are not supported yet.";
	
	public static val String IMPLICIT_TO_OPTIONAL_IS_NOT_SUPPORTED = "Implicit construction of optionals in %s is not yet supported. Please use 'optional.some' instead.";
	
	public static val String SIZE_INFERENCE_FAILED_FOR_RETURN = "Could not infer the size of the function's return.";
	
	public static val String MUST_BE_USED_IMMEDIATELY_MSG = "%s must be used immediately. %s";
	public static val String MUST_BE_USED_IMMEDIATELY_CODE = "must_be_used_immediately";
	
	public static val String SIGINST_MODALITY_CANT_BE_FUNC_PARAM_MSG = "Signal instances and modalities cannot be passed as parameters.";
	
	@Inject extension ExtensionMethodHelper

	@Inject extension ProgramDslTypeInferrer inferrer
	@Inject ITypeSystem typeSystem
	@Inject TypeValidator validator
	@Inject PluginResourceLoader loader
	@Inject ElementSizeInferrer elementSizeInferrer
	@Inject ModelUtils modelUtils
		
	@Check(CheckType.NORMAL)
	def checkElementSizeInference(VariableDeclaration variable) {
		if(EcoreUtil2.getContainerOfType(variable, SystemResourceSetup) !== null) return;
		
		val sizeInferenceResult = elementSizeInferrer.infer(variable);
		val invalidElements = sizeInferenceResult.invalidSelfOrChildren;
		for(invalidElement : invalidElements) {
			if(invalidElement.typeOf !== null && invalidElement.typeOf.type.name == "array") {
			}
			else {
				var invalidObj = if(invalidElement.root?.eResource == variable.eResource) {
					invalidElement.root
				} else {
					variable
				}
				
				error('Cannot determine size of element: ' + (invalidElement as InvalidElementSizeInferenceResult).message,
					invalidObj,
					invalidObj?.eClass?.EAllAttributes?.head)		
			}
		}
	}
	
	@Check(CheckType.NORMAL)
	def checkSiginstOrModalityIsUsedImediately(FeatureCall featureCall) {
		val isSiginst = featureCall.feature instanceof SignalInstance;
		val isModality = featureCall.feature instanceof Modality;
		if(!(isSiginst || isModality)) return;

		val container = featureCall.eContainer;
		if (container instanceof FeatureCall) {
			if (container.feature instanceof GeneratedFunctionDefinition) {
				return
			}
		} else if (container instanceof Argument) {
			val operation = container.eContainer;
			if (operation instanceof ElementReferenceExpression) {
				if (operation.reference instanceof GeneratedFunctionDefinition) {
					return
				}
			}
		}

		val featureName = (featureCall.feature as NamedElement).name;
		val msg = if (isModality) {
				String.format(MUST_BE_USED_IMMEDIATELY_MSG, "Modalities", '''Add .read() after «featureName»''')
			} else {
				String.format(MUST_BE_USED_IMMEDIATELY_MSG,
					"Signal instances", '''Add .read() or .write() after «featureName»''')
			}
		error(msg, featureCall, ExpressionsPackage.Literals.FEATURE_CALL__FEATURE, MUST_BE_USED_IMMEDIATELY_CODE);
	}

	@Check(CheckType.NORMAL)
	def checkSetup_platformValidator(SystemResourceSetup setup) {
		val systemResource = if (setup.type instanceof AbstractSystemResource) {
				setup.type as AbstractSystemResource;
			}

		runLibraryValidator(setup.eContainer as Program, setup, systemResource.eResource, systemResource.validator);
	}

	@Check(CheckType.NORMAL)
	def checkProgram_platformValidator(Program program) {
		val platform = modelUtils.getPlatform(program);
		if (platform === null) {
			//TODO: 
//			error(String.format(NO_PLATFORM_SELECTED_MSG, LibraryExtensions.descriptors.filter[optional].map[id].join(", ")), program, ProgramPackage.eINSTANCE.program_EventHandlers,
//				NO_PLATFORM_SELECTED_CODE);
		} else {
			runLibraryValidator(program, platform, platform.eResource, platform.validator);
		}
	}
	
	@Check(CheckType.NORMAL)
	def checkVariableDeclaration_hasValidType(VariableDeclaration variable) {
		val explicitType = variable.typeSpecifier;
		if(explicitType === null) return;
		
		val initialization = variable.initialization;
		if(initialization === null) return;
		
		val explicitTypeInfered = inferrer.infer(explicitType);
		val initializationTypeInfered = inferrer.infer(initialization);
		validator.assertAssignable(explicitTypeInfered, initializationTypeInfered, 
			String.format(ExpressionsTypeInferrerMessages.ASSIGNMENT_OPERATOR, AssignmentOperator.ASSIGN, explicitTypeInfered?.type, initializationTypeInfered?.type), 
			this);
	}


	@Check(CheckType.FAST)
	def checkVariableDeclaration_isUniqueInProgramBlock(VariableDeclaration variable) {
		val parentBlock = EcoreUtil2.getContainerOfType(variable, ProgramBlock);
		if(parentBlock === null) return;

		val variablesInBlock = parentBlock.content.filter(VariableDeclaration);
		val conflictingVariable = variablesInBlock.findFirst[x|x != variable && x.name == variable.name];
		if (conflictingVariable !== null) {
			error(String.format(VARIABLE_NOT_UNIQUE_MSG, variable.name), variable,
				TypesPackage.Literals.NAMED_ELEMENT__NAME, VARIABLE_NOT_UNIQUE_CODE);
		}
	}

	def runLibraryValidator(Program program, EObject context, Resource validatorOrigin, String validatorClassName) {
		if (validatorClassName !== null) {
			try {
				val validator = loader.loadFromPlugin(validatorOrigin, validatorClassName) as IResourceValidator;
				validator.validate(program, context, this);
			} catch (Exception e) {
				// TODO: add this to the error log
				e.printStackTrace();
			}
		}
	}

	@Check(CheckType.FAST)
	override checkOperationArguments_FeatureCall(FeatureCall call) {
		val feature = call.feature
		if (feature instanceof Operation) {
			if(!call.isOperationCall) {
				error(FUNCTIONS_CAN_NOT_BE_REFERENCED_MSG, call, ExpressionsPackage.eINSTANCE.featureCall_Feature, FUNCTIONS_CAN_NOT_BE_REFERENCED_CODE);
			}
			
			if (call.owner !== null && feature.isExtensionMethodOn(inferrer.infer(call.owner, this)?.type)) {
				assertOperationArguments(feature, combine(call.owner, call.expressions));
			} else {
				assertOperationArguments(feature, call.expressions);
			}
		}
	}

	@Check(CheckType.FAST)
	def checkMixedNamedParameters(ArgumentExpression it) {
		if (!(arguments.forall[argument|argument.parameter !== null] || arguments.forall [ argument |
			argument.parameter === null
		])) {
			error(MIXED_PARAMS_MSG, null, ProgramDslValidator.MIXED_PARAMS_CODE);
		}
	}
	
	@Check(CheckType.FAST)
	def checkNewInstanceExpression(NewInstanceExpression npe) {
		// check type is a generated type
		val type = npe.^type?.type;
		if(!(type instanceof GeneratedType)) {
			error('Can only instantiate generated types', npe, ProgramPackage.eINSTANCE.newInstanceExpression_Type);
		}
	}

	override assertOperationArguments(Operation op, List<Expression> args) {
		val parameters = op.parameters
		if (args.size() < parameters.filter[!optional].size || args.size > parameters.size) {
			error(String.format(WRONG_NR_OF_ARGS_MSG, parameters.map[type]), null, WRONG_NR_OF_ARGS_CODE);
		}
	}

	@Check(CheckType.NORMAL)
	def checkNoReturnValueForVoidOperation(FunctionDefinition op) {
		if(typeSystem.isSame(op.getType(), typeSystem.getType(VOID))) {
			EcoreUtil2.getAllContentsOfType(op.body, ReturnStatement)
				.filter[x | x.value !== null ]
				.forEach [ error(VOID_OP_CANNOT_RETURN_VALUE_MSG, it, null) ];
		}
	}

	@Check(CheckType.FAST)
	def checkNoModalityOrSiginstParameters(FunctionDefinition op) {
		val hasModalityOrSiginstParam = op.parameters.findFirst[ it.type.name == 'modality' || it.type.name == 'siginst' ]
		if(hasModalityOrSiginstParam !== null) {
			error(SIGINST_MODALITY_CANT_BE_FUNC_PARAM_MSG, hasModalityOrSiginstParam, TypesPackage.Literals.TYPED_ELEMENT__TYPE_SPECIFIER);
		}
	}
	
	@Check(CheckType.FAST)
	def checkNoReturnValueForEventHandler(EventHandlerDeclaration op) {
		EcoreUtil2.getAllContentsOfType(op.block, ReturnStatement)
			.filter[x | x.value !== null ]
			.forEach [ error(VOID_OP_CANNOT_RETURN_VALUE_MSG, it, null) ];
	}

	@Check(CheckType.NORMAL)
	def checkReturnStatementsAreCompatibleToReturnType(FunctionDefinition op) {
		val operationType = inferrer.infer(op, this);
		if (typeSystem.isSuperType(operationType.getType(), typeSystem.getType(VOID))) {
			return;
		}
		if (op.body.content.isEmpty()) {
			error(String.format(MISSING_RETURN_VALUE_MSG, operationType), op, TypesPackage.Literals.NAMED_ELEMENT__NAME);
			return;
		}

		val returnStatements = EcoreUtil2.getAllContentsOfType(op.getBody(), ReturnStatement);
		for (ReturnStatement rs : returnStatements) {
			val rsType = inferrer.infer(rs, this);
			if(rsType === null) {
				error(String.format(INCOMPATIBLE_RETURN_TYPE_MSG, 'void', operationType), rs, ProgramPackage.eINSTANCE.returnStatement_Value);
			} else {
				validator.assertAssignable(operationType, rsType,
					String.format(INCOMPATIBLE_RETURN_TYPE_MSG, rsType, operationType), [issue | 
						error(issue.getMessage, rs, ProgramPackage.eINSTANCE.returnStatement_Value)
					])				
			}
			
		}
	}
	
	// Forbid returning structs/generics etc. (allow void, primitive) (via validator), until implemented.
	@Check(CheckType.NORMAL)
	def checkFunctionReturnTypeIsPrimitive(FunctionDefinition op) {
		val operationType = ModelUtils.toSpecifier(inferrer.infer(op, this));
		if(!(op instanceof GeneratedFunctionDefinition) && typeSystem.isSame(operationType?.type, typeSystem.getType(VOID)) || ModelUtils.isPrimitiveType(operationType)) {
			return;
		}
		
		// TODO: At the moment we allow too much. Reduce this to strings/arrays/structs and implement the rules described
		//       in #120.
		val opSize = elementSizeInferrer.infer(op);
		if(!(opSize instanceof ValidElementSizeInferenceResult)) {
			error(SIZE_INFERENCE_FAILED_FOR_RETURN, op, TypesPackage.Literals.NAMED_ELEMENT__NAME);
			return;
		}
		warning(FUNCTION_RETURN_TYPE_NOT_PRIMITIVE_MSG, op, TypesPackage.Literals.NAMED_ELEMENT__NAME);
	}

	@Check(CheckType.NORMAL)
	def checkIfCondition(IfStatement it) {
		assertIsBoolean(condition)
	}

	@Check(CheckType.NORMAL)
	def checkWhileStatement(WhileStatement it) {
		assertIsBoolean(condition)
	}

	@Check(CheckType.NORMAL)
	def checkDoWhileCondition(DoWhileStatement it) {
		assertIsBoolean(condition)
	}
	
	@Check(CheckType.NORMAL)
	def checkVariableDeclaration(VariableDeclaration it){
		var result1 = inferrer.infer(it)
		var result2 = inferrer.infer(typeSystem.getType(ITypeSystem.VOID))
		if(result1.type.equals(result2.type)) {
			error(VOID_VARIABLE_TYPE, it, null);
		}
	}
	
	def protected assertIsBoolean(Expression exp) {
		var result1 = inferrer.infer(exp)
		var result2 = inferrer.infer(typeSystem.getType(ProgramDslTypeInferrer.BOOL_LITERAL_TYPE))
		validator.assertCompatible(result1, result2, null, [issue | error(issue.getMessage, exp, null)])

	}
		
	def protected assertIsInteger(Expression exp, String outerMessage) {
		var result1 = inferrer.infer(exp)
		var result2 = inferrer.infer(typeSystem.getType(ITypeSystem.INTEGER))
		validator.assertCompatible(result1, result2, null, [issue | error(String.format(outerMessage?:"%s", issue.getMessage), exp, null)])
	}
	
	@Check(CheckType.NORMAL)
	def checkStructLiteralsHaveCorrectNumberOfArgumentsAndTheirTypesMatch(ElementReferenceExpression exp) {
		val ref = exp.reference;
		if(ref instanceof StructureType) {
			if(exp.isOperationCall) {
				if(ref.parameters.length != exp.arguments.length) {
					error(String.format(ERROR_WRONG_NUMBER_OF_ARGUMENTS_MSG, ref.parameters.map[it.type].toString), exp, null);
					return;
				}
				
				val parmsToArgs = ModelUtils.getSortedArgumentsAsMap(ref.parameters, exp.arguments);				
				parmsToArgs.entrySet.forEach[parm_arg | 
					val sField = parm_arg.key;
					val sArg = parm_arg.value.value;
					val t1 = inferrer.infer(sField, this);
					val t2 = inferrer.infer(sArg, this);
					validator.assertAssignable(t1, t2,
						
					// message says t2 can't be assigned to t1, --> invert in format
					String.format(INCOMPATIBLE_TYPES_MSG, t2, t1), [issue | error(issue.getMessage, sArg, null)])
				]
			}
		}
	}
	

	// allow assignment on struct members, derefs, array index
	override checkLeftHandAssignment(AssignmentExpression expression) {
		val varRef = expression.varRef;
		var EObject innerExpr = varRef;
		var nested = true;
		while(nested) {
			if(innerExpr instanceof FeatureCall) {
				if(!innerExpr.operationCall) {
					innerExpr = innerExpr.feature;	
				}
				else {
					nested = false;
				}
			}
			else if(innerExpr instanceof ElementReferenceExpression) {
				innerExpr = innerExpr.reference;
			}
			else if(innerExpr instanceof DereferenceExpression) {
				innerExpr = innerExpr.innerReference;
			}
			else if(innerExpr instanceof ArrayAccessExpression) {
				// we can't assign on slices, so we don't unnest here
				if(innerExpr.arraySelector instanceof ValueRange) {
					nested = false;
				}
				else {
					innerExpr = innerExpr.owner;	
				}
			}
			else {
				nested = false;
			}
		}
		if(innerExpr instanceof VariableDeclaration || innerExpr instanceof FunctionParameterDeclaration || innerExpr instanceof Parameter || innerExpr instanceof Property) {
			return;
		}
		
		super.checkLeftHandAssignment(expression);
	}
	
	@Check(CheckType.FAST)
	def checkOptionalParametersInFunctionDeclarations(FunctionParameterDeclaration parameter) {
		if (parameter.isOptional) {
			error(OPTIONAL_PARAMETERS_NOT_IMPLEMENTED_MSG, parameter, ProgramPackage.Literals.FUNCTION_PARAMETER_DECLARATION__VALUE, OPTIONAL_PARAMETERS_NOT_IMPLEMENTED_CODE)
		}
	}
	
	@Check(CheckType.FAST)
	def arrayLiteralsCantBeEmpty(ArrayLiteral lit) {
		if(lit.values.empty) {
			error(ARRAY_LITERALS_CANT_BE_EMPTY, lit, null);
		}
		else {
			// only do this check if lit has values
			arrayLiteralsMustBeHomogenous(lit);
		}
	}
	
	def arrayLiteralsMustBeHomogenous(ArrayLiteral lit) {
		val typesInArray = lit.values.map[ModelUtils.toSpecifier(inferrer.infer(it, this))];
		val typesInArrayGrouped = typesInArray.groupBy[ModelUtils.typeSpecifierIdentifier(it)]
		if(typesInArrayGrouped.size > 1) {
			error(ARRAY_LITERAL_IS_NOT_HOMOGENOUS, lit, null);
		}
		else {
			if(lit.eAllContents.toIterable.filter(ArrayLiteral).empty === false) {
				error(NESTED_ARRAY_LITERALS_NOT_SUPPORTED, lit, null);
			}
			
		}
	}
	
	@Check(CheckType.NORMAL)
	def checkTypesAreNotNestedGeneratedTypes(VariableDeclaration declaration) {
		if(EcoreUtil2.getContainerOfType(declaration, SystemResourceSetup) !== null) return;
		checkTypesAreNotNestedGeneratedTypes(declaration, declaration.infer);
	}
	
	@Check(CheckType.NORMAL)
	def checkTypesAreNotNestedGeneratedTypes(FunctionDefinition fd) {
		val infType = fd.infer;
		checkTypesAreNotNestedGeneratedTypes(fd, infType);
	}
	
	@Check(CheckType.NORMAL)
	def checkTypesAreNotNestedGeneratedTypes(TypeSpecifier ts) {
		val infType = ts.infer;
		checkTypesAreNotNestedGeneratedTypes(ts, infType);
	}
	
	protected def checkTypesAreNotNestedGeneratedTypes(EObject obj, InferenceResult ir) {
		checkTypesAreNotNestedGeneratedTypes(obj, ir, false, false);
	}
	
	protected def void checkTypesAreNotNestedGeneratedTypes(EObject obj, InferenceResult ir, Boolean hasGeneratedType, Boolean containsReferenceTypes) {
		if(ir === null) {
			return;
		}
		var hasGeneratedTypeNext = hasGeneratedType;
		var containsReferenceTypesNext = containsReferenceTypes;
		val type = ir.type;
		val subTypes = if(type instanceof GeneratedType) {
			if(type.name == "reference") {
				if(hasGeneratedTypeNext) {
					error(NESTED_GENERATED_TYPES_ARE_NOT_SUPPORTED, obj, null);
					return;
				}
				else {
					containsReferenceTypesNext = true;
				}
			}
			else if(hasGeneratedTypeNext || containsReferenceTypesNext) {
				error(NESTED_GENERATED_TYPES_ARE_NOT_SUPPORTED, obj, null);
				return;
			}
			else {
				// we support nested references, but no other generated nested types. 
				// if references are nested, no other generated types must be part of the type,
				// since references don't recurse properly at codegen
				hasGeneratedTypeNext = true;
			}
			
			ir.bindings;
		}
		else if(type instanceof ComplexType) {
			if(type instanceof StructureType) {
				type.parameters.map[it.typeSpecifier.infer];
			}
			else if(type instanceof SumType) {
				type.alternatives.flatMap[alt | 
					if(alt instanceof NamedProductType) {
						alt.parameters.map[it.typeSpecifier.infer]	
					}
					else if(alt instanceof AnonymousProductType) {
						alt.typeSpecifiers.map[infer]
					}
					else {
						#[]
					}
				]
			}
		}
		else {
			newArrayList
		}
		
		// We don't have nested types so there is nothing to check.
		if(subTypes === null) return;
		
		val hasGeneratedTypeNextFinal = hasGeneratedTypeNext;
		val containsReferenceTypesNextFinal = containsReferenceTypesNext;	
		subTypes.filterNull.forEach[
			ModelUtils.preventRecursion(it.type, [| 
				checkTypesAreNotNestedGeneratedTypes(obj, it, hasGeneratedTypeNextFinal, containsReferenceTypesNextFinal);
				return null;
			]);
		];
		
	}
	
	
	@Check(CheckType.FAST)
	def arrayLiteralsCantBeUsedInGlobalScope(ValueRange lit) {
		val EObject fun = EcoreUtil2.getContainerOfType(lit, FunctionDefinition)?:EcoreUtil2.getContainerOfType(lit, EventHandlerDeclaration);
		if(fun === null) {
			error(ARRAY_SLICES_ARE_NOT_SUPPORTED_TOP_LEVEL, lit, null);
		}
	}
	
	@Check(CheckType.NORMAL)
	def arrayElementAccessIndexCheck(ArrayAccessExpression expr) {
		val item = expr.owner;
		val sizeInfRes = elementSizeInferrer.infer(item);
		
		if(!(expr.arraySelector instanceof ValueRange)) {
			expr.arraySelector?.assertIsInteger(ARRAY_INDEX_MUST_BE_INTEGER);
		}	
		
		val staticVal = StaticValueInferrer.infer(expr.arraySelector, [x|]);
		val isInferred = (sizeInfRes instanceof ValidElementSizeInferenceResult) && staticVal instanceof Integer;
		if(isInferred) {
			val idx = staticVal as Integer;
			val len = (sizeInfRes as ValidElementSizeInferenceResult).elementCount;
			if(idx < 0 || len <= idx) {
				error(String.format(ARRAY_INDEX_OUT_OF_BOUNDS, len), expr, ProgramPackage.Literals.ARRAY_ACCESS_EXPRESSION__ARRAY_SELECTOR);
			}
		}
	}
	
	@Check(CheckType.NORMAL)
	def arrayRangeChecks(ValueRange range) {
		val errorFun1 = [String s | error(s, range, null)];
		val errorFun2 = [String s | error(String.format(ARRAY_RANGE_INVALID, s), range, null)];
		val expr = (range.eContainer as ArrayAccessExpression).owner;
		val typ = inferrer.infer(expr, this);
		if(typ.type.name != "array") {
			errorFun1.apply(ARRAY_RANGE_ONLY_ON_ARRAY);
		}
		
		range.lowerBound?.assertIsInteger(ARRAY_RANGE_INVALID)
		range.upperBound?.assertIsInteger(ARRAY_RANGE_INVALID)

		val lengthOfArrayIR = elementSizeInferrer.infer(expr);
		val lengthOfArray = if(lengthOfArrayIR instanceof ValidElementSizeInferenceResult) {
			lengthOfArrayIR.elementCount;
		}
		val lowerBound = StaticValueInferrer.infer(range.lowerBound, [x|])?:0
		val upperBound = StaticValueInferrer.infer(range.upperBound, [x|])?:lengthOfArray
		
		if((lowerBound as Integer) < 0) {
			errorFun2.apply("Lower bound must be positive or zero");
		}
		
		if(upperBound !== null) {
			val size = elementSizeInferrer.infer(expr);
			if(size.valid) {
				if((upperBound as Integer) > (size as ValidElementSizeInferenceResult).elementCount) {
					errorFun2.apply(String.format("Upper bound must be less than or equal to array size (%s)", (size as ValidElementSizeInferenceResult).elementCount));
				}
				else if((upperBound as Integer) <= 0) {
					errorFun2.apply("Upper bound must be strictly positive");
				}
			}
		}
		if(lowerBound !== null && upperBound !== null) {
			if(lowerBound as Integer >= upperBound as Integer) {
				errorFun2.apply("Lower bound must be smaller than upper bound");
			}
		}
	}
	
	@Check(CheckType.NORMAL)
	def noUpcastingToOptionalsInFunctionArguments(ElementReferenceExpression eref) {
		val typesAndArgs = ModelUtils.getFunctionCallArguments(eref);
		if(typesAndArgs === null) return;
		
		typesAndArgs.forEach[ts_arg | 
			val ts = ts_arg.key;
			if(ts.type instanceof GeneratedType && ts.type.name == "optional") {
				val arg = ts_arg.value;
				val argType = ModelUtils.toSpecifier(inferrer.infer(arg.value));
				if(ModelUtils.typeSpecifierEqualsWith([t1, t2 | typeSystem.haveCommonType(t1, t2)], ts.typeArguments.head, argType)) {
					error(String.format(IMPLICIT_TO_OPTIONAL_IS_NOT_SUPPORTED, "function calls"), arg, null);
				}
			}
		]
	}
	
	@Check(CheckType.NORMAL)
	def noUpcastingToOptionalsInReturns(ReturnStatement stmt) {
		val funDef = EcoreUtil2.getContainerOfType(stmt, FunctionDefinition);
		if(funDef === null) {
			return;
		}
		
		val retType = inferrer.infer(funDef);
		if(retType.type instanceof GeneratedType && retType.type.name == "optional") {
			val returnedValueType = inferrer.infer(stmt.value);
			if(stmt.value instanceof PrimitiveValueExpression) {
				error(String.format(IMPLICIT_TO_OPTIONAL_IS_NOT_SUPPORTED, "returns"), stmt, null);
			}
		}
	} 
}
