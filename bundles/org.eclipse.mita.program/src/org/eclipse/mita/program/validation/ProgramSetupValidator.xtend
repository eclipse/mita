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
import org.eclipse.mita.base.types.TypesPackage
import org.eclipse.mita.platform.Instantiability
import org.eclipse.mita.program.ProgramPackage
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.xtext.validation.AbstractDeclarativeValidator
import org.eclipse.xtext.validation.Check
import org.eclipse.xtext.validation.CheckType
import org.eclipse.xtext.validation.EValidatorRegistrar

class ProgramSetupValidator extends AbstractDeclarativeValidator {
	public static val String INCOMPATIBLE_VALUE_TYPE_MSG = "The type '%s' is not compatible with the configuration item's type '%s'";
	public static val String INCOMPATIBLE_VALUE_TYPE_CODE = "incompatible_value_type";
	
	public static val String CONFIG_ITEM_VALUE_NOT_UNIQUE_MSG = "Cannot redeclare configuration item value '%s'";
	public static val String CONFIG_ITEM_VALUE_NOT_UNIQUE_CODE = "config_item_value_not_unique";
	
	public static val String SETUP_MUST_HAVE_NAME_MSG = "Connectivity setup blocks have to be named, e.g. '%s'";
	public static val String SETUP_MUST_HAVE_NAME_CODE = "setup_must_have_name";
	
	public static val String SETUP_MUST_NOT_HAVE_NAME_MSG = "Cannot assign a to this system resource.";
	public static val String SETUP_MUST_NOT_HAVE_NAME_CODE = "setup_most_not_have_name";
	
	public static val MISSING_CONIGURATION_ITEM_CODE = 'missing_config_item'
	
	@Check(CheckType.FAST)
	def checkConfigurationItemValues(SystemResourceSetup setup) {

		// check config item values are unique
		setup.configurationItemValues.groupBy[x| x.item?.name ].entrySet.filter[x|x.value.length > 1].forEach [ x |
			error(String.format(CONFIG_ITEM_VALUE_NOT_UNIQUE_MSG, x.key), x.value.last,
				ProgramPackage.eINSTANCE.configurationItemValue_Item, CONFIG_ITEM_VALUE_NOT_UNIQUE_MSG);
		]

		// check all mandatory config items are present
		var missingConfigItems = setup.type?.configurationItems
		?.filter[required] // item is mandatory
		?.filter[!setup.configurationItemValues.map[c|c.item].contains(it)] // item is not contained in setup
		if (missingConfigItems === null || !missingConfigItems.empty) {
			error('Missing configuration items: ' + missingConfigItems.map[c|c.name].join(', '), null,
				MISSING_CONIGURATION_ITEM_CODE)
		}
	}

	@Check(CheckType.FAST)
	def checkSystemResourceSetup_uniqueSignalInstances(SystemResourceSetup setup) {
		val vcivGroups = setup.signalInstances.groupBy[x|x.name];
		for (group : vcivGroups.entrySet) {
			if (group.value.length > 1) {
				error(String.format(ProgramDslValidator.VARIABLE_NOT_UNIQUE_MSG, group.key), group.value.last,
					TypesPackage.Literals.NAMED_ELEMENT__NAME, ProgramDslValidator.VARIABLE_NOT_UNIQUE_CODE);
			}
		}
	}
	
	@Check(CheckType.FAST)
	def checkSetupNaming(SystemResourceSetup setup) {
		val setupType = setup.type;
		if(setupType?.instantiable == Instantiability.MANY || setupType?.instantiable == Instantiability.NAMED_SINGLETON) {
			// must be named
			if(setup.name === null || setup.name.trim.empty) {
				val proposal = '''setup «setupType.name.toFirstLower» : «setupType.name» { }'''
				error(String.format(SETUP_MUST_HAVE_NAME_MSG, proposal), setup,
					ProgramPackage.Literals.SYSTEM_RESOURCE_SETUP__TYPE, SETUP_MUST_HAVE_NAME_CODE);
			}
		} else if(setupType?.instantiable == Instantiability.NONE) {
			// cannot be named
			if(setup.name !== null && !setup.name.trim.empty) {
				error(ProgramSetupValidator.SETUP_MUST_NOT_HAVE_NAME_MSG, setup,
					ProgramPackage.Literals.SYSTEM_RESOURCE_SETUP__NAME, SETUP_MUST_NOT_HAVE_NAME_CODE);
			}
		}
	}
	
	@Check(CheckType.FAST)
	def checkSetupIsSingleton(SystemResourceSetup setup) {
		if(setup.type?.instantiable == Instantiability.NONE || setup.type?.instantiable == Instantiability.NAMED_SINGLETON) {
			val allSetupsForThisType = setup.eResource.resourceSet.allContents
				.filter(SystemResourceSetup)
				.filter[ it.type?.name == setup.type?.name ];
			if(!allSetupsForThisType.tail.empty) {
				// more than two setups for this system resource exist. That's a problem.
				error("This system resource must only be setup once", setup, ProgramPackage.Literals.SYSTEM_RESOURCE_SETUP__TYPE);
			}
		}
	}
	
	@Inject
	override register(EValidatorRegistrar registrar) {
		// Do not register because this validator is only a composite #398987
	}
	
}