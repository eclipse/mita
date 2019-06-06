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
import java.util.HashSet
import java.util.Set
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EStructuralFeature
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.mita.base.expressions.Argument
import org.eclipse.mita.base.expressions.ArgumentExpression
import org.eclipse.mita.base.expressions.ArrayAccessExpression
import org.eclipse.mita.base.expressions.AssignmentExpression
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.ExpressionsPackage
import org.eclipse.mita.base.expressions.FeatureCall
import org.eclipse.mita.base.expressions.FeatureCallWithoutFeature
import org.eclipse.mita.base.expressions.ValueRange
import org.eclipse.mita.base.types.ExceptionTypeDeclaration
import org.eclipse.mita.base.types.Expression
import org.eclipse.mita.base.types.GeneratedType
import org.eclipse.mita.base.types.GenericElement
import org.eclipse.mita.base.types.NamedElement
import org.eclipse.mita.base.types.Parameter
import org.eclipse.mita.base.types.PresentTypeSpecifier
import org.eclipse.mita.base.types.Property
import org.eclipse.mita.base.types.TypeAccessor
import org.eclipse.mita.base.types.TypeParameter
import org.eclipse.mita.base.types.TypeReferenceSpecifier
import org.eclipse.mita.base.types.TypeSpecifier
import org.eclipse.mita.base.types.TypesPackage
import org.eclipse.mita.base.types.typesystem.ITypeSystem
import org.eclipse.mita.base.typesystem.BaseConstraintFactory
import org.eclipse.mita.base.typesystem.infra.MitaBaseResource
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.base.util.PreventRecursion
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.platform.Connectivity
import org.eclipse.mita.platform.Modality
import org.eclipse.mita.platform.Sensor
import org.eclipse.mita.program.ArrayLiteral
import org.eclipse.mita.program.DereferenceExpression
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.FunctionDefinition
import org.eclipse.mita.program.FunctionParameterDeclaration
import org.eclipse.mita.program.GeneratedFunctionDefinition
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.ProgramBlock
import org.eclipse.mita.program.ProgramPackage
import org.eclipse.mita.program.ReturnStatement
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.inferrer.InvalidElementSizeInferenceResult
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.inferrer.ValidElementSizeInferenceResult
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.mita.program.resource.PluginResourceLoader
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.diagnostics.Severity
import org.eclipse.xtext.validation.Check
import org.eclipse.xtext.validation.CheckType
import org.eclipse.xtext.validation.ComposedChecks

import static org.eclipse.mita.base.types.typesystem.ITypeSystem.VOID
import org.eclipse.mita.base.types.TypeUtils

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

	public static val String ERROR_ASSIGNMENT_TO_CONST_CODE = "AssignmentToConst";
	public static val String ERROR_ASSIGNMENT_TO_CONST_MSG = "Assignment to constant not allowed.";

	public static final String ERROR_LEFT_HAND_ASSIGNMENT_CODE = "LeftHandAssignment";
	public static final String ERROR_LEFT_HAND_ASSIGNMENT_MSG = "The left-hand side of an assignment must be a variable.";

	@Inject ITypeSystem typeSystem
	@Inject PluginResourceLoader loader
	@Inject ModelUtils modelUtils
		
	def featureOrNull(EStructuralFeature ref, EObject object) {
		if(object === null || ref === null || object.eClass.getEStructuralFeature(ref.getName()) !== ref) {
			return null;
		}
		return ref;
	}
	@Check(CheckType.FAST)
	def attachTypingIssues(Program program) {
		val resource = program.eResource;
		val solution = TypeUtils.getConstraintSolution(resource);
		if(solution === null) {
			return;
		}
		val issues = solution.issues
			.map[MitaBaseResource.resolveProxy(program.eResource, it.target) -> it]
			.filter[it.key !== null]
			.groupBy[it.value.message->EcoreUtil.getURI(it.key)].values.map[it.head]
			.filter[it.key.eResource == program.eResource];
		issues.toSet.filter[it.value.severity == Severity.ERROR].forEach[
			error(it.value.message, it.key, it.value.feature.featureOrNull(it.key), 0, it.value.issueCode, #[]);
		]
		issues.toSet.filter[it.value.severity == Severity.WARNING].forEach[
			warning(it.value.message, it.key, it.value.feature.featureOrNull(it.key), 0, it.value.issueCode, #[]);
		]
		issues.toSet.filter[it.value.severity == Severity.INFO].forEach[
			info(it.value.message, it.key, it.value.feature.featureOrNull(it.key), 0, it.value.issueCode, #[]);
		]
	}
	
//	@Check(CheckType.NORMAL)
//	def arrayElementAccessIndexCheck(ArrayAccessExpression expr) {
//		val item = expr.owner;
//		val sizeInfRes = elementSizeInferrer.infer(item);
//				
//		val staticVal = StaticValueInferrer.infer(expr.arraySelector, [x|]);
//		val isInferred = (sizeInfRes instanceof ValidElementSizeInferenceResult) && staticVal instanceof Long;
//		if(isInferred) {
//			val idx = staticVal as Long;
//			val len = (sizeInfRes as ValidElementSizeInferenceResult).elementCount;
//			if(idx < 0 || len <= idx) {
//				error(String.format(ARRAY_INDEX_OUT_OF_BOUNDS, len), expr, ExpressionsPackage.Literals.ARRAY_ACCESS_EXPRESSION__ARRAY_SELECTOR);
//			}
//		}
//	}
	
	@Check(CheckType.FAST) 
	def void checkValidTypesForPresentTypeSpecifier(PresentTypeSpecifier ts) {
		if(EcoreUtil2.getContainerOfType(ts, SystemResourceSetup) === null) {
			val typeRef = TypesPackage.eINSTANCE.typeReferenceSpecifier_Type;
			val type = BaseUtils.getType(ts);
			val eClassName = TypeUtils.getConstraintSystem(ts.eResource)?.getUserData(type, BaseConstraintFactory.ECLASS_KEY);
			if(#[ExceptionTypeDeclaration, Sensor, Connectivity].map[it.simpleName].contains(eClassName)) {
				error('''Cannot use «eClassName» as type here''', ts, typeRef);
			}
			if(eClassName == TypeParameter.simpleName) {
				var Iterable<AbstractType> typeParameterTypes = #[];
				var EObject prev = ts;
				var container = EcoreUtil2.getContainerOfType(ts, GenericElement);
				while(container !== null && container !== prev) {
					typeParameterTypes = typeParameterTypes + container.typeParameters.map[BaseUtils.getType(it)];
					prev = container;
					container = EcoreUtil2.getContainerOfType(ts, GenericElement);
				}
				if(!typeParameterTypes.exists[it == type]) {
					error('''Couldn't resolve reference to Type '«BaseUtils.getText(ts, typeRef)»'.''', ts, typeRef);
				} 	
			}
			// otherwise we didn't get a type for this
			else if(type instanceof TypeVariable) {
				val resolvedReference = ts.eGet(TypesPackage.eINSTANCE.typeReferenceSpecifier_Type, false);
				if(resolvedReference instanceof EObject) {
					val genericElement = EcoreUtil2.getContainerOfType(resolvedReference, GenericElement);
					if(genericElement !== null) {
						if(EcoreUtil2.isAncestor(genericElement, ts)) {
							// ts refers a type variable declared in a parent.
							return;
						}
					}
				}
				error('''Couldn't resolve reference to Type '«BaseUtils.getText(ts, typeRef)»'.''', ts, typeRef);
			}
		}
	}
	
	@Check(CheckType.FAST) 
	def void checkAssignmentToFinalVariable(AssignmentExpression exp) {
		val Expression varRef = exp.getVarRef()
		val EObject referencedObject = if (varRef instanceof ElementReferenceExpression) {
			varRef.reference
		}
		if (referencedObject instanceof Property) {
			if (referencedObject.isConst()) {
				error(ERROR_ASSIGNMENT_TO_CONST_MSG, ExpressionsPackage.Literals.ASSIGNMENT_EXPRESSION__VAR_REF,
					ERROR_ASSIGNMENT_TO_CONST_CODE)
			}
		}
	}
	
	@Check(CheckType.NORMAL)
	def checkFunctionsReturnSomething(FunctionDefinition funDef) {
		val returnType = BaseUtils.getType(funDef.typeSpecifier);
		if(returnType !== null && returnType.name != "void") {
			if(funDef.eAllContents.filter(ReturnStatement).empty) {
				error(String.format(MISSING_RETURN_VALUE_MSG, returnType), funDef, TypesPackage.eINSTANCE.namedElement_Name, MISSING_RETURN_VALUE_CODE);
			}
		}
	}
	
//	@Check(CheckType.NORMAL)
//	def checkElementSizeInference(VariableDeclaration variable) {[|
//		if(EcoreUtil2.getContainerOfType(variable, SystemResourceSetup) !== null) return;
//		
//		val sizeInferenceResult = elementSizeInferrer.infer(variable);
//		val invalidElements = sizeInferenceResult.invalidSelfOrChildren;
//		for(invalidElement : invalidElements) {
//			if(invalidElement.typeOf instanceof TypeReferenceSpecifier && (invalidElement.typeOf as TypeReferenceSpecifier).type.name == "array") {
//			}
//			else {
//				val invalidObj = if(invalidElement.root?.eResource == variable.eResource) {
//					invalidElement.root
//				} else {
//					variable
//				}
//				
//				val invalidRef = if(invalidObj instanceof VariableDeclaration) {
//					TypesPackage.eINSTANCE.namedElement_Name
//				}
//				
//				error('Cannot determine size of element: ' + (invalidElement as InvalidElementSizeInferenceResult).message,
//					invalidObj, invalidRef)		
//			}
//		}
//	].apply()}
	
	@Check(CheckType.NORMAL)
	def checkSiginstOrModalityIsUsedImediately(ElementReferenceExpression featureCall) {[|
		val isSiginst = featureCall.reference instanceof SignalInstance;
		val isModality = featureCall.reference instanceof Modality;
		if(!(isSiginst || isModality)) return;

		val container = featureCall.eContainer;
		if (container instanceof ElementReferenceExpression) {
			if (container.reference instanceof GeneratedFunctionDefinition) {
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

		val featureName = (featureCall.reference as NamedElement).name;
		val msg = if (isModality) {
				String.format(MUST_BE_USED_IMMEDIATELY_MSG, "Modalities", '''Add .read() after «featureName»''')
			} else {
				String.format(MUST_BE_USED_IMMEDIATELY_MSG,
					"Signal instances", '''Add .read() or .write() after «featureName»''')
			}
		error(msg, featureCall, ExpressionsPackage.Literals.ELEMENT_REFERENCE_EXPRESSION__REFERENCE, MUST_BE_USED_IMMEDIATELY_CODE);
	].apply()}

	@Check(CheckType.NORMAL)
	def checkSetup_platformValidator(SystemResourceSetup setup) {
		val systemResource = if (setup.type instanceof AbstractSystemResource) {
				setup.type as AbstractSystemResource;
			}

		runLibraryValidator(setup.eContainer as Program, setup, systemResource.eResource, systemResource.validator);
	}
	
	@Check(CheckType.NORMAL)
	def checkProgram_platformValidator(Program program) {
		val platform = modelUtils.getPlatform(program.eResource.resourceSet, program);
		if (platform !== null) { 
			runLibraryValidator(program, platform, platform.eResource, platform.validator);
		}
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
				if(validator !== null) {
					if(validatorOrigin instanceof MitaBaseResource)	{
						if(validatorOrigin.latestSolution === null) {
							validatorOrigin.collectAndSolveTypes(validatorOrigin.contents.head);
						}
					}				
					validator.validate(program, context, this);
				}
			} catch (Exception e) {
				// TODO: add this to the error log
				e.printStackTrace();
			}
		}
	}

	@Check(CheckType.FAST)
	def checkMixedNamedParameters(ArgumentExpression expr) {
		val arguments = if(expr instanceof FeatureCall && !(expr instanceof FeatureCallWithoutFeature)) {
			expr.arguments.tail;
		}
		else {
			expr.arguments;
		}
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
		val hasModalityOrSiginstParam = op.parameters.findFirst[ 
			it.type?.name == 'modality' || it.type?.name == 'siginst'
		]
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
	
//	// Forbid returning structs/generics etc. (allow void, primitive) (via validator), until implemented.
//	@Check(CheckType.NORMAL)
//	def checkFunctionReturnTypeIsPrimitive(FunctionDefinition op) {[|
//		val operationType = BaseUtils.getType(op.typeSpecifier); 
//		if(!(op instanceof GeneratedFunctionDefinition) && (op instanceof AtomicType && op.name == "void") || ModelUtils.isPrimitiveType(operationType, op)) {
//			return;
//		}
//		
//		// TODO: At the moment we allow too much. Reduce this to strings/arrays/structs and implement the rules described
//		//       in #120.
//		val opSize = elementSizeInferrer.infer(op);
//		if(!(opSize instanceof ValidElementSizeInferenceResult)) {
//			error(SIZE_INFERENCE_FAILED_FOR_RETURN, op, TypesPackage.Literals.NAMED_ELEMENT__NAME);
//			return;
//		}
//		warning(FUNCTION_RETURN_TYPE_NOT_PRIMITIVE_MSG, op, TypesPackage.Literals.NAMED_ELEMENT__NAME);
//	].apply()}
	
	@Check(CheckType.NORMAL)
	def checkVariableDeclaration(VariableDeclaration varDecl){
		val varType = BaseUtils.getType(varDecl);
		if(varType?.name == "void") {
			error(VOID_VARIABLE_TYPE, varDecl, null);
		}
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
	}
		
	@Check(CheckType.NORMAL)
	def checkTypesAreNotNestedGeneratedTypes(VariableDeclaration declaration) {
		if(EcoreUtil2.getContainerOfType(declaration, SystemResourceSetup) !== null) return;
		checkTypesAreNotNestedGeneratedTypes(declaration, BaseUtils.getType(declaration));
	}
	@Check(CheckType.NORMAL)
	def checkParametersAreAssignedOnlyOnce(ElementReferenceExpression functionCall) {
		if(functionCall.isOperationCall) {
			val arguments = functionCall.arguments;
			val Set<String> usedParams = new HashSet();
			arguments.filter[it.parameter !== null].forEach[
				if(usedParams.contains(it.parameter.name)) {
					error("Duplicate assignment to parameter " + it.parameter.name + ".", it, null, 0);
				}
				else {
					usedParams.add(it.parameter.name);
				}
			]
		}
	}
	
	@Check(CheckType.NORMAL)
	def checkTypesAreNotNestedGeneratedTypes(FunctionDefinition fd) {
		val infType = BaseUtils.getType(fd);
		checkTypesAreNotNestedGeneratedTypes(fd, infType);
	}
	
	@Check(CheckType.NORMAL)
	def checkTypesAreNotNestedGeneratedTypes(TypeSpecifier ts) {
		val infType = BaseUtils.getType(ts);
		checkTypesAreNotNestedGeneratedTypes(ts, infType);
	}
	
	protected def checkTypesAreNotNestedGeneratedTypes(EObject obj, AbstractType ir) {
		checkTypesAreNotNestedGeneratedTypes(obj, ir, false, false);
	}
	
	protected def void checkTypesAreNotNestedGeneratedTypes(EObject obj, AbstractType type, Boolean hasGeneratedType, Boolean containsReferenceTypes) {
		if(type === null) {
			return;
		}
		var hasGeneratedTypeNext = hasGeneratedType;
		var containsReferenceTypesNext = containsReferenceTypes;

		val subTypes = if(type instanceof TypeConstructorType) {
			if(TypeUtils.isGeneratedType(obj, type)) {
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
			}
			type.typeArguments.tail;
		}
		else {
			#[];
		}
		
		// We don't have nested types so there is nothing to check.
		if(subTypes === null) return;
		
		val hasGeneratedTypeNextFinal = hasGeneratedTypeNext;
		val containsReferenceTypesNextFinal = containsReferenceTypesNext;	
		subTypes.filterNull.forEach[
			PreventRecursion.preventRecursion(it, [| 
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
		
//	@Check(CheckType.NORMAL)
//	def arrayRangeChecks(ValueRange range) {
//		val errorFun1 = [String s | error(s, range, null)];
//		val errorFun2 = [String s | error(String.format(ARRAY_RANGE_INVALID, s), range, null)];
//		val expr = EcoreUtil2.getContainerOfType(range, ArrayAccessExpression).owner;
//		
//		val lengthOfArrayIR = elementSizeInferrer.infer(expr);
//		val lengthOfArray = if(lengthOfArrayIR instanceof ValidElementSizeInferenceResult) {
//			lengthOfArrayIR.elementCount;
//		}
//		val lowerBound = StaticValueInferrer.infer(range.lowerBound, [x|])?:0L
//		val upperBound = StaticValueInferrer.infer(range.upperBound, [x|])?:lengthOfArray
//				
//		if((lowerBound as Long) < 0) {
//			errorFun2.apply("Lower bound must be positive or zero");
//		}
//		
//		if(upperBound !== null) {
//			val size = elementSizeInferrer.infer(expr);
//			if(size.valid) {
//				if((upperBound as Long) > (size as ValidElementSizeInferenceResult).elementCount) {
//					errorFun2.apply(String.format("Upper bound must be less than or equal to array size (%s)", (size as ValidElementSizeInferenceResult).elementCount));
//				}
//				else if((upperBound as Long) <= 0) {
//					errorFun2.apply("Upper bound must be strictly positive");
//				}
//			}
//		}
//		if(lowerBound !== null && upperBound !== null) {
//			if(lowerBound as Long >= upperBound as Long) {
//				errorFun2.apply("Lower bound must be smaller than upper bound");
//			}
//		}
//	}
	
	@Check(CheckType.FAST) 
	def void checkLeftHandAssignment(AssignmentExpression expression) {
		val varRef = expression.varRef;
		var EObject innerExpr = varRef;
		var nested = true;
		while (nested) {
			if (innerExpr instanceof ElementReferenceExpression) {
				if (innerExpr.arguments.size > 0) {
					innerExpr = innerExpr.arguments.head.value;
				} else {
					innerExpr = (innerExpr as ElementReferenceExpression).reference;
				}
			} else if (innerExpr instanceof DereferenceExpression) {
				innerExpr = innerExpr.innerReference;
			} else if (innerExpr instanceof ArrayAccessExpression) {
				// we can't assign on slices, so we don't unnest here
				if (innerExpr.arraySelector instanceof ValueRange) {
					nested = false;
				} else {
					innerExpr = innerExpr.owner;
				}
			} else {
				nested = false;
			}
		}
		if (innerExpr instanceof VariableDeclaration || innerExpr instanceof FunctionParameterDeclaration ||
			innerExpr instanceof TypeAccessor || innerExpr instanceof Property) {
			return;
		}
		
		else if (varRef instanceof ElementReferenceExpression) {
			var EObject referencedObject = ((varRef as ElementReferenceExpression)).getReference()
			if (!(referencedObject instanceof Property) && !(referencedObject instanceof Parameter)) {
				error(ERROR_LEFT_HAND_ASSIGNMENT_MSG, ExpressionsPackage.Literals.ASSIGNMENT_EXPRESSION__VAR_REF,
					ERROR_LEFT_HAND_ASSIGNMENT_CODE)
			}
		} else {
			error(ERROR_LEFT_HAND_ASSIGNMENT_MSG, ExpressionsPackage.Literals.ASSIGNMENT_EXPRESSION__VAR_REF,
				ERROR_LEFT_HAND_ASSIGNMENT_CODE)
		}
	}
}
