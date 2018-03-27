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

package org.eclipse.mita.types.scoping

import org.eclipse.mita.library.^extension.LibraryExtensions
import com.google.inject.Inject
import java.util.Collections
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.impl.ResourceSetImpl
import org.eclipse.xtext.resource.IEObjectDescription
import org.eclipse.xtext.resource.IResourceServiceProvider
import org.yakindu.base.types.Type
import org.yakindu.base.types.TypesPackage
import org.yakindu.base.types.typesystem.GenericTypeSystem
import org.yakindu.base.types.typesystem.ITypeSystem

class MitaTypeSystem extends GenericTypeSystem {

	@Inject
	protected TypesLibraryProvider libraryProvider

	public static val ITERABLE_TYPE = "iterable"
	public static val REFERENCE_TYPE = "reference";
	public static val OPTINAL_TYPE = "optional";
	public static val SIGINST_TYPE = "siginst";
	public static val MODALITY_TYPE = "modality";
	public static val ARRAY_TYPE = "array";
	public static val INT32_TYPE = "int32";
	public static val DOUBLE_TYPE = "double";
	public static val FLOAT_TYPE = "float";
	public static val BOOL_TYPE = "bool";

	private static var MitaTypeSystem INSTANCE = new MitaTypeSystem()

	private var nativeTypesLoaded = false;

	protected new() {
	}

	static def MitaTypeSystem getInstance() {
		return INSTANCE
	}

	override protected initRegistries() {
		super.initRegistries()
		getType(ITypeSystem.INTEGER).abstract = true
		getType(ITypeSystem.REAL).abstract = true
		getType(ITypeSystem.BOOLEAN).abstract = true
		getType(ITypeSystem.ANY).abstract = true
		getType(ITypeSystem.STRING).abstract = true
	}

	override getType(String type) {
		val result = super.getType(type)
		if (result === null) {
			lazyLoadNativeTypes()
			return super.getType(type)
		}
		result
	}

	override getTypes() {
		lazyLoadNativeTypes()
		super.getTypes()
	}

	protected def lazyLoadNativeTypes() {
		if (!nativeTypesLoaded) {
			// Load native types from stdlibs
			LibraryExtensions.defaultLibraries.map[resourceUris].flatten.toSet.forEach [
				exportedTypes.forEach [ type |
					declareType(type.EObjectOrProxy as Type, (type.EObjectOrProxy as Type).name)
				]
			]
			nativeTypesLoaded = true
		}
	}

	def Iterable<IEObjectDescription> getExportedTypes(URI libraryUri) {
		val set = new ResourceSetImpl();
		val resource = set.getResource(libraryUri, true);

		val registry = IResourceServiceProvider.Registry.INSTANCE
		val resourceServiceProvider = registry.getResourceServiceProvider(libraryUri)
		if (resourceServiceProvider === null) {
			return Collections.emptySet()
		}
		val resourceDescriptionManager = resourceServiceProvider.getResourceDescriptionManager()
		if (resourceDescriptionManager === null) {
			return Collections.emptySet();
		}
		val resourceDescription = resourceDescriptionManager.getResourceDescription(resource);
		if (resourceDescription === null) {
			return Collections.emptySet();
		}
		return resourceDescription.getExportedObjectsByType(TypesPackage.Literals.TYPE);
	}

}
