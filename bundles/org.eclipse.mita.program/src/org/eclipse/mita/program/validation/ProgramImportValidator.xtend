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
import java.util.Collections
import java.util.HashSet
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.mita.base.types.PackageAssociation
import org.eclipse.mita.base.types.TypesPackage
import org.eclipse.mita.library.^extension.LibraryExtensions
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.model.ImportHelper
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.validation.AbstractDeclarativeValidator
import org.eclipse.xtext.validation.Check
import org.eclipse.xtext.validation.CheckType
import org.eclipse.xtext.validation.EValidatorRegistrar
import org.eclipse.mita.program.ProgramPackage

class ProgramImportValidator extends AbstractDeclarativeValidator {

	@Inject extension ImportHelper
	
	public static val String NO_PLATFORM_SELECTED_MSG = "No platform selected. Please import one of the available platforms: \"%s.\"";
	public static val String NO_PLATFORM_SELECTED_CODE = "no_platform_selected";
	
	public static val String MULTIPLE_PLATFORMS_SELECTED_MSG = "Only one target platform must be imported."
	public static val String MULTIPLE_PLATFORMS_SELECTED_CODE = "multiple_platforms_selected"

	@Check(CheckType.NORMAL)
	def checkPackageImportsAreUnique(Program program) {
		val pkgsSeen = new HashSet<String>();
		for (i : program.imports) {
			val pkgName = i.importedNamespace
			if (pkgName !== null && pkgsSeen.contains(pkgName)) {
				error('''Re-importing the "«pkgName»" package.''', i,
					TypesPackage.eINSTANCE.importStatement_ImportedNamespace)
			}
			pkgsSeen.add(pkgName);
		}
	}

	@Check(CheckType.NORMAL)
	def checkPackageImportExists(Program program) {
		val availablePackages = program.eResource.visiblePackages
		program.imports.forEach [
			if (!availablePackages.contains(importedNamespace))
				error('''Package '«importedNamespace»' does not exist.''', it,
					TypesPackage.eINSTANCE.importStatement_ImportedNamespace)
		]
	}

	@Check(CheckType.NORMAL)
	def checkPlatformImportIsPresent(Program program) {
		val availablePackages = LibraryExtensions.availablePlatforms.map[id].toSet
		val importedPlatforms = program.imports.filter[availablePackages.contains(importedNamespace)]
		val needsPlatformImport = !program.name.startsWith("stdlib");
		if (needsPlatformImport && importedPlatforms.nullOrEmpty) {
			error(String.format(NO_PLATFORM_SELECTED_MSG, LibraryExtensions.descriptors.filter[optional].map[id].join(", ")), program, ProgramPackage.eINSTANCE.program_EventHandlers,
				NO_PLATFORM_SELECTED_CODE)
		} else if (importedPlatforms.size > 1) {
			importedPlatforms.forEach[ import | 
				error(MULTIPLE_PLATFORMS_SELECTED_MSG, import,
					TypesPackage.Literals.IMPORT_STATEMENT__IMPORTED_NAMESPACE, MULTIPLE_PLATFORMS_SELECTED_CODE, import.importedNamespace)
			]
		}
	}

	/**
	 * Users need to import a platform even if they're not using on of its resources,
	 * as the platform provides other basic elements such as exception handling or the event loop.
	 */
	// @Check(CheckType.NORMAL)
	def checkForUnsuedImports(Program program) {
		val imports = program.imports.toSet
		val requiredImports = EcoreUtil.CrossReferencer.find(Collections.singletonList(program)).keySet.map [
			EcoreUtil2.getContainerOfType(it, PackageAssociation)
		].toSet

		val requiredImportNames = requiredImports.map[name].toSet
		imports.forEach [
			if (!requiredImportNames.contains(it.importedNamespace)) {
				warning('''The import «it.importedNamespace»' is never used.''', it,
					TypesPackage.eINSTANCE.importStatement_ImportedNamespace)
			}
		]
	}

	@Inject
	override register(EValidatorRegistrar registrar) {
		// Do not register because this validator is only a composite #398987
	}

}
