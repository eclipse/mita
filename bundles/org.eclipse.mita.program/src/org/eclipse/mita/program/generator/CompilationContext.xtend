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
import org.eclipse.mita.base.types.GeneratedType
import org.eclipse.mita.base.types.TypeParameter
import org.eclipse.mita.base.types.TypeSpecifier
import org.eclipse.mita.base.types.inferrer.ITypeSystemInferrer
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.platform.Platform
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.ThrowExceptionStatement
import org.eclipse.mita.program.TimeIntervalEvent
import org.eclipse.mita.program.TryStatement
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.generator.internal.IResourceGraph
import org.eclipse.mita.program.generator.internal.ResourceGraphBuilder
import org.eclipse.mita.program.model.ModelUtils

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
	
	private var Boolean isInited = false;

	public def init(Iterable<Program> compilationUnits, Iterable<Program> stdLib) {
		if(isInited) {
			throw new IllegalStateException("CompilationContext.init was called twice");
		}
		
		isInited = true;
		
		units = compilationUnits;
		buildResourceGraph();
		
		stdlib = stdLib;
		systemResourceSetups = compilationUnits.map[it.setup].flatten.toSet();
		
		eventHandler = compilationUnits.map[x|x.eventHandlers].flatten.toList();
		platform = modelUtils.getPlatform(compilationUnits.head);
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
	
	public def Iterable<Program> getAllUnits() {
		assertInited();
		return units;
	}

	public def Iterable<SystemResourceSetup> getAllSystemResourceSetup() {
		assertInited();
		return systemResourceSetups;
	}
	
	public def SystemResourceSetup getSetupFor(AbstractSystemResource resource) {
		assertInited();
		return allSystemResourceSetup.findFirst[ EcoreUtil.getID(it.type) == EcoreUtil.getID(resource) ];
	}
	
	public def Iterable<EventHandlerDeclaration> getAllEventHandlers() {
		assertInited();
		return eventHandler;
	}
	
	def hasTimeEvents() {
		assertInited();
		return units.exists[unit | unit.eventHandlers.exists[e| e.event instanceof TimeIntervalEvent ] ]
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
		return (unitAndStdlibExceptions + platformExceptions).groupBy[it.name].entrySet.map[it.value.head];
	}
		
	public def getAllGeneratedTypesUsed(ITypeSystemInferrer typeInferrer) {
		assertInited();
		return (units + stdlib).flatMap[program |
			(   program.eAllContents.filter(TypeSpecifier) + 
				program.eAllContents.filter(VariableDeclaration).map[
					ModelUtils.toSpecifier(typeInferrer.infer(it))
				]
			).filterNull.filter[
				it.type !== null && it.type instanceof GeneratedType && noUnboundTypeParameters(it)
			].toIterable
		].groupBy[ModelUtils.typeSpecifierIdentifier(it)].entrySet.map[it.value.head];
	}
	
	public def getResourceGraph() {
		assertInited();
		return resourceGraph;
	}
	
	private def Boolean noUnboundTypeParameters(TypeSpecifier specifier) {
		assertInited();
		if(specifier.type instanceof TypeParameter) {
			return false;
		}
		return specifier.typeArguments.map[noUnboundTypeParameters].fold(true, [x, y | x && y]);
	}

}
