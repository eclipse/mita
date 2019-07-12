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

package org.eclipse.mita.program.generator

import com.google.inject.Inject
import com.google.inject.Provider
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.mita.base.types.ExceptionTypeDeclaration
import org.eclipse.mita.base.typesystem.types.TypeScheme
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.platform.Platform
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.ThrowExceptionStatement
import org.eclipse.mita.program.TimeIntervalEvent
import org.eclipse.mita.program.TryStatement
import org.eclipse.mita.program.generator.internal.IResourceGraph
import org.eclipse.mita.program.generator.internal.ResourceGraphBuilder
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.mita.base.types.TypeUtils

class CompilationContext {
	protected Iterable<Program> units;
	
	protected Iterable<Program> stdlib;
	
	protected Iterable<SystemResourceSetup> systemResourceSetups;
	
	protected Iterable<EventHandlerDeclaration> eventHandler;

	protected Platform platform;
	
	protected IResourceGraph<EObject> resourceGraph;
	
	@Inject
	protected Provider<ResourceGraphBuilder> resourceGraphBuilderProvider;
	
	@Inject
	protected ModelUtils modelUtils;
	
	@Accessors
	protected String mitaVersion = "0.2.0";
	
	var Boolean isInited = false;

	def init(Iterable<Program> compilationUnits, Iterable<Program> stdLib) {
		if(isInited) {
			throw new IllegalStateException("CompilationContext.init was called twice");
		}
		
		isInited = true;
		
		units = compilationUnits;
		buildResourceGraph();
		
		stdlib = stdLib;
		systemResourceSetups = compilationUnits.map[it.setup].flatten.toSet();
		
		eventHandler = compilationUnits.map[x|x.eventHandlers].flatten.toList();
		platform = modelUtils.getPlatform(units.head.eResource.resourceSet, compilationUnits.head);
	}
	
	private def assertInited() {
		if(!isInited) {
			throw new IllegalStateException("CompilationContext.init was not called");
		}
	}
	
	protected def buildResourceGraph() {
		assertInited();
		val resourceGraphBuilder = resourceGraphBuilderProvider.get();
		allUnits.forEach[ resourceGraphBuilder.addNode(it) ];
		val resourceGraph = resourceGraphBuilder.build();
		if(!resourceGraph.isDAG) {
			throw new UnsupportedOperationException("Cannot initialize resources with circular dependencies");
		}
		
		this.resourceGraph = resourceGraph;
	}
	
	def Iterable<Program> getAllUnits() {
		assertInited();
		return units;
	}

	def Iterable<SystemResourceSetup> getAllSystemResourceSetup() {
		assertInited();
		return systemResourceSetups;
	}
	
	def SystemResourceSetup getSetupFor(AbstractSystemResource resource) {
		assertInited();
		return allSystemResourceSetup.findFirst[ EcoreUtil.getID(it.type) == EcoreUtil.getID(resource) ];
	}
	
	def Iterable<EventHandlerDeclaration> getAllEventHandlers() {
		assertInited();
		return eventHandler;
	}
	
	def hasTimeEvents() {
		assertInited();
		return units.exists[unit | 
			unit.eventHandlers.exists[e| 
				e.event instanceof TimeIntervalEvent
			]
		]
	}
	
	def hasGlobalVariables() {
		assertInited();
		return units.exists[!globalVariables.empty]
	}
	
	def getAllExceptionsUsed() {
		assertInited();
		val unitAndStdlibExceptions = (units + stdlib).flatMap[program | 
			program.eAllContents.filter(ExceptionTypeDeclaration).toIterable +
			program.eAllContents.filter(ThrowExceptionStatement).map[it.exceptionType].toIterable +
			program.eAllContents.filter(TryStatement).flatMap[x | x.catchStatements.map[it.exceptionType].iterator].toIterable
		];
		val platformExceptions = platform.eResource.allContents.filter(ExceptionTypeDeclaration).toIterable();
		return (unitAndStdlibExceptions + platformExceptions).filterNull.groupBy[it.name].entrySet.map[it.value.head];
	}
		
	def getAllGeneratedTypesUsed() {
		assertInited();
		return (units + stdlib).flatMap[program |
			(program.eAllContents).map[
				it -> BaseUtils.getType(it)
			].filter[
				!(it.value instanceof TypeScheme) && TypeUtils.isGeneratedType(program.eResource, it.value)
			].toIterable
		].groupBy[it.value.toString].entrySet
		.map[it.value.head.value];
	}
	
	def getResourceGraph() {
		assertInited();
		return resourceGraph;
	}
}
