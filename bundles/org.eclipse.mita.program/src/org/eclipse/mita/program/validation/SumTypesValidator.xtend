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
import org.eclipse.emf.common.util.EList
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.Argument
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.FeatureCall
import org.eclipse.mita.base.types.AnonymousProductType
import org.eclipse.mita.base.types.HasAccessors
import org.eclipse.mita.base.types.NamedProductType
import org.eclipse.mita.base.types.Singleton
import org.eclipse.mita.base.types.StructureType
import org.eclipse.mita.base.types.SumAlternative
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor
import org.eclipse.mita.base.types.validation.TypeValidator
import org.eclipse.mita.platform.validation.PlatformDSLValidator
import org.eclipse.mita.program.IsAssignmentCase
import org.eclipse.mita.program.IsDeconstructionCase
import org.eclipse.mita.program.IsOtherCase
import org.eclipse.mita.program.WhereIsStatement
import org.eclipse.mita.program.inferrer.ProgramDslTypeInferrer
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.xtext.validation.AbstractDeclarativeValidator
import org.eclipse.xtext.validation.Check
import org.eclipse.xtext.validation.CheckType
import org.eclipse.xtext.validation.EValidatorRegistrar

class SumTypesValidator extends AbstractDeclarativeValidator implements IValidationIssueAcceptor {
	
	@Inject ProgramDslTypeInferrer inferrer
	@Inject TypeValidator validator
	
	public static val String CANT_USE_BOTH_NAMED_AND_ANONYMOUS_DECONSTRUCTORS_MSG = "Deconstruction cases must not mix named and anonymous deconstructors";
	
	public static val String CANT_DECONSTRUCT_SINGLETONS_MSG = "Can't deconstruct singletons";
	
	public static val String CANT_ASSIGN_SINGLETONS_MSG = "Can't assign singletons";
	
	public static val String DEFAULT_CASE_MUST_BE_LAST_CASE_MSG = "Default case must be the last case";
	
	public static val String ERROR_WRONG_NUMBER_OF_DECONSTRUCTORS_MSG = "Wrong number of deconstructors, expected %s."
	
		
	@Check(CheckType.FAST)
	def checkIsDeconstructionCaseHasOnlyOneTypeOfDeconstructor(IsDeconstructionCase deconstructionCase) {
		val namedConstructor = deconstructionCase.deconstructors.map[it.productMember !== null];
		// there must not be both named and anonymous deconstructors
		if(namedConstructor.containsAll(#[true, false])) {
			error(CANT_USE_BOTH_NAMED_AND_ANONYMOUS_DECONSTRUCTORS_MSG, deconstructionCase, null);
		}
	} 

	@Check
	def checkIsOtherCaseIsLastCase(IsOtherCase otherCase) {
		val whereIsStatement = otherCase.eContainer as WhereIsStatement;
		if(whereIsStatement.isCases.indexOf(otherCase) != (whereIsStatement.isCases.length - 1)) {
			error(DEFAULT_CASE_MUST_BE_LAST_CASE_MSG, otherCase, null);
		}
	}
	
	@Check
	def checkDeconstructorsHaveCorrectNumberOfArguments(IsDeconstructionCase deconstructionCase) {
		val realType = deconstructionCase.productType.realType;
		// named deconstruction fields already are OK due to scoping
		if(deconstructionCase.anonymous) {
			// check that we deconstruct at most as many fields as realType has
			val fieldsTypes = if(realType instanceof HasAccessors) {
				realType.accessorsTypes;
			}
			else {
				// realType is some embedded type we don't handle further
				#[realType];
			}
			if(deconstructionCase.deconstructors.length > fieldsTypes.length) {
				error(String.format(ERROR_WRONG_NUMBER_OF_DECONSTRUCTORS_MSG, fieldsTypes.length), deconstructionCase, null);
				return;
			}
		}
	}
	
	@Check
	def checkSumAlternativeConstructorsHaveCorrectArgumentsForFeatureCall(FeatureCall fc) {
		val ref = fc.feature;
		if(ref instanceof SumAlternative) {
			checkSumAlternativeConstructorsHaveCorrectArguments(fc, fc.arguments, ref);
		}
	}
	
	@Check
	def checkSumAlternativeConstructorsHaveCorrectArgumentsForERef(ElementReferenceExpression eref) {
		val ref = eref.reference;
		if(ref instanceof SumAlternative) {
			checkSumAlternativeConstructorsHaveCorrectArguments(eref, eref.arguments, ref);
		}
	}
	
	def checkSumAlternativeConstructorsHaveCorrectArguments(EObject obj, EList<Argument> arguments, SumAlternative ref) {

			val realType = ref.realType;
			val realArgs = if(realType instanceof HasAccessors) {
				realType.accessorsTypes;
			}
			else {
				#[realType];
			}
			
			if(realArgs.length != arguments.length) {
				error(String.format(PlatformDSLValidator.ERROR_WRONG_NUMBER_OF_ARGUMENTS_MSG, realArgs.toString), obj, null);
				return;
			}
			
			if(ref instanceof NamedProductType) {
				var argsSorted = ModelUtils.getSortedArguments(ref.parameters, arguments);

				for(arg_type: ModelUtils.zip(argsSorted, realArgs)) {
					val sArg = arg_type.key.value;
					val sField = arg_type.value;
					val t1 = inferrer.infer(sField, this);
					val t2 = inferrer.infer(sArg, this);
					validator.assertAssignable(t1, t2,
						// message says t2 can't be assigned to t1, --> invert in format
						String.format(ProgramDslValidator.INCOMPATIBLE_TYPES_MSG, t2, t1), [issue | error(issue.getMessage, sArg, null)])
				}
			}
			else if(ref instanceof AnonymousProductType) {
				val realTypeSpecifiers = if(realType instanceof StructureType) {
					realType.parameters.map[it.typeSpecifier];
				} else {
					ref.typeSpecifiers;
				}
				if(realTypeSpecifiers.length != arguments.length) {
					error(String.format(PlatformDSLValidator.ERROR_WRONG_NUMBER_OF_ARGUMENTS_MSG, realTypeSpecifiers.map[it.type].toString), obj, null);
					return;
				}
				if(realType instanceof StructureType) {
					var argsSorted = ModelUtils.getSortedArguments(realType.parameters, arguments);
					for(arg_type: ModelUtils.zip(argsSorted, realArgs)) {
						val sArg = arg_type.key.value;
						val sField = arg_type.value;
						val t1 = inferrer.infer(sField, this);
						val t2 = inferrer.infer(sArg, this);
						validator.assertAssignable(t1, t2,
							// message says t2 can't be assigned to t1, --> invert in format
							String.format(ProgramDslValidator.INCOMPATIBLE_TYPES_MSG, t2, t1), [issue | error(issue.getMessage, sArg, null)])
					}
				}
				else {
					for(var i = 0; i < realTypeSpecifiers.length; i++) {
						val sField = realTypeSpecifiers.get(i);
						val sArg = arguments.get(i).value;
						val t1 = inferrer.infer(sField, this);
						val t2 = inferrer.infer(sArg, this);
						validator.assertAssignable(t1, t2,
							// message says t2 can't be assigned to t1, --> invert in format
							String.format(ProgramDslValidator.INCOMPATIBLE_TYPES_MSG, t2, t1), [issue | error(issue.getMessage, sArg, null)])
					}
				}
			}
		
	}
	
	
	@Check(CheckType.FAST)
	def checkIsAssignmentCaseCantAssignSingletons(IsAssignmentCase assignmentCase) {
		if(assignmentCase.assignmentVariable.typeSpecifier.type instanceof Singleton) {
			error(CANT_ASSIGN_SINGLETONS_MSG, assignmentCase.assignmentVariable, null);
		}
	}
	
	@Check(CheckType.FAST)
	def checkIsDeconstructionCaseCantDestructSingletons(IsDeconstructionCase deconstructionCase) {
		if(deconstructionCase.productType instanceof Singleton) {
			error(CANT_DECONSTRUCT_SINGLETONS_MSG, deconstructionCase, null);
		}
	}
	
	@Inject
	override register(EValidatorRegistrar registrar) {
		// Do not register because this validator is only a composite #398987
	}
	
	override accept(ValidationIssue issue) {
		error(issue.message, issue.target, null);
	}
	
}