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
import org.eclipse.mita.base.types.GeneratedElement
import org.eclipse.mita.base.types.GeneratedType
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.program.GeneratedFunctionDefinition
import org.eclipse.mita.program.generator.AbstractFunctionGenerator
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.AbstractTypeGenerator
import org.eclipse.mita.program.generator.IGenerator
import org.eclipse.mita.program.resource.PluginResourceLoader

/**
 * Creates and maintains the component generators associated with a platform.
 */
@Singleton
class GeneratorRegistry {

	@Inject
	protected PluginResourceLoader loader

	private final LoadingCache<GeneratedElement, Optional<IGenerator>> generatorCache = CacheBuilder.newBuilder().
		build(new CacheLoader<GeneratedElement, Optional<IGenerator>>() {
			
			override Optional<IGenerator> load(GeneratedElement elem) {
				val result = loader.loadFromPlugin(elem.eResource, elem.generator) as IGenerator
				if (result === null) {
					return Optional.absent
				}
				return Optional.of(result)
			}
		});

	def getGenerator(AbstractSystemResource resource) {
		generatorCache.get(resource).orNull as AbstractSystemResourceGenerator;
	}

	def AbstractTypeGenerator getGenerator(GeneratedType type) {
		generatorCache.get(type).orNull as AbstractTypeGenerator;
	}

	def AbstractFunctionGenerator getGenerator(GeneratedFunctionDefinition function) {
		generatorCache.get(function).orNull as AbstractFunctionGenerator;
	}
}
