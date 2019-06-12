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

package org.eclipse.mita.program.generator.internal

import com.google.common.base.Optional
import com.google.common.cache.CacheBuilder
import com.google.common.cache.CacheLoader
import com.google.common.cache.LoadingCache
import com.google.inject.Inject
import com.google.inject.Singleton
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.types.GeneratedType
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.program.GeneratedFunctionDefinition
import org.eclipse.mita.program.generator.AbstractFunctionGenerator
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.AbstractTypeGenerator
import org.eclipse.mita.program.generator.IGenerator
import org.eclipse.mita.program.resource.PluginResourceLoader
import org.eclipse.mita.base.typesystem.BaseConstraintFactory
import org.eclipse.mita.base.types.TypesUtil

/**
 * Creates and maintains the component generators associated with a platform.
 */
@Singleton
class GeneratorRegistry {

	@Inject
	protected PluginResourceLoader loader

	final LoadingCache<Pair<Resource, String>, Optional<IGenerator>> generatorCache = CacheBuilder.newBuilder().
		build(new CacheLoader<Pair<Resource, String>, Optional<IGenerator>>() {
			
			override Optional<IGenerator> load(Pair<Resource, String> elem) {
				val result = loader.loadFromPlugin(elem.key, elem.value) as IGenerator
				if (result === null) {
					return Optional.absent
				}
				return Optional.of(result)
			}
		});

	def getGenerator(Resource eResource, AbstractType type) {
		val generatorString = TypesUtil.getConstraintSystem(eResource).getUserData(type, BaseConstraintFactory.GENERATOR_KEY);
		if(generatorString !== null) {
			return generatorCache.get(eResource -> generatorString).orNull
		}
		return null;
	}

	def getGenerator(AbstractSystemResource resource) {
		if(resource?.generator === null) {
			return null;
		}
		generatorCache.get(resource.eResource -> resource.generator).orNull as AbstractSystemResourceGenerator;
	}

	def AbstractTypeGenerator getGenerator(GeneratedType type) {
		if(type?.generator === null) {
			return null;
		}
		generatorCache.get(type.eResource -> type.generator).orNull as AbstractTypeGenerator;
	}

	def AbstractFunctionGenerator getGenerator(GeneratedFunctionDefinition function) {
		if(function?.generator === null) {
			return null;
		}
		generatorCache.get(function.eResource -> function.generator).orNull as AbstractFunctionGenerator;
	}
}
