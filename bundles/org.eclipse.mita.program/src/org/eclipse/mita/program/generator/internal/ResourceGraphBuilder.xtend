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

import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.platform.Platform
import org.eclipse.mita.program.ModalityAccess
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.SystemEventSource
import org.eclipse.mita.program.SystemResourceSetup
import com.google.inject.Inject
import java.util.Collections
import java.util.HashSet
import java.util.List
import java.util.Map
import java.util.Set
import java.util.TreeMap
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.yakindu.base.expressions.expressions.ElementReferenceExpression
import org.yakindu.base.types.inferrer.ITypeSystemInferrer

class ResourceGraphBuilder {
	
	@Inject
	protected ITypeSystemInferrer typeSystemInferrer
	
	protected final Set<Object> nodes = new HashSet();
	
	protected dispatch def Iterable<EObject> doComputeDependencies(Program program) {
		val siginstAccess =  
			program.eAllContents
			.filter(SignalInstance)
			.map[ it.eContainer ]
			.filter(EObject)
			.toSet
			
		val modalityAccess = program.eAllContents
			.filter(ModalityAccess)
			.map[ it.preparation.systemResource ]
			.filter(EObject)
			.toList
			
		val eventsHandled = program.eventHandlers
			.filter[ it.event instanceof SystemEventSource ]
			.map[ (it.event as SystemEventSource).origin ]
			.filter[ !(it instanceof Platform) ]
			
		return siginstAccess + modalityAccess + eventsHandled;
	}
	
	protected dispatch def Iterable<EObject> doComputeDependencies(AbstractSystemResource resource) {
		return resource
			.configurationItems
			.filter[ typeSystemInferrer.infer(it)?.type instanceof AbstractSystemResource ]
			.filter(EObject)
			.toList;
	}
	
	protected dispatch def Iterable<EObject> doComputeDependencies(SystemResourceSetup setup) {
		return setup.eAllContents
			.filter(ElementReferenceExpression)
			.map[ it.reference ]
			.filter[ it instanceof AbstractSystemResource || it instanceof SystemResourceSetup ]
			.filter(EObject)
			.toList();
	}
	
	protected dispatch def Iterable<EObject> doComputeDependencies(EObject obj) {
		return Collections.emptyList();
	}
	
	protected def Iterable<EObject> computeDependencies(EObject obj) {
		return obj.doComputeDependencies();
	}
	
	static enum NodeMark { None, Temp, Perm }
	
	static class GraphIsNotAcyclicException extends Exception { }
	
	@Inject
	IQualifiedNameProvider qualifiedNameProvider

	protected Map<String, NodeMark> nodeMarks = new TreeMap();
	protected Map<String, List<String>> edges = new TreeMap();
	protected Iterable<EObject> sortedNodes = #[];
	protected boolean isDag = true;
	
	/**
	 * Adds a new node to this graph.
	 * 
	 * BEWARE: For each node added to this graph we need to be able to compute its dependencies
	 *         and a valid ID (e.g. using the QualifiedNameProvider). If we cannot compute the dependencies
	 *         an empty list is assumed (which might be wrong). If we cannot compute a unique ID
	 *         an {@link IllegalArgumentException} is thrown.
	 */
	def addNode(EObject node) {
		node.visit();
	}
	
	protected def void visit(EObject node) {
		val nodeId = node.ID;
		if(nodeId === null) throw new IllegalArgumentException("Cannot compute an ID for the node");
		
		val mark = nodeMarks.getOrDefault(nodeId, NodeMark.None);
		if(mark == NodeMark.Perm) return;
		if(mark == NodeMark.Temp) {
			isDag = false;
			return;
		}
		
		nodeMarks.put(nodeId, NodeMark.Temp);
		edges.put(nodeId, node.computeDependencies.map[ 
			visit(it);
			return it.ID;
		].toList());
		nodeMarks.put(nodeId, NodeMark.Perm);
		
		sortedNodes = sortedNodes + #[node];
	}
	
	def IResourceGraph<EObject> build() {
		return new ResourceGraphImpl(sortedNodes, edges.entrySet.flatMap[a| a.value.map[b| a.key -> b]], isDag);
	}
	
	protected def String getID(EObject obj) {
		val fqn = qualifiedNameProvider.getFullyQualifiedName(obj)?.toString();
		return fqn ?: computeID(obj);
	}
	
	protected dispatch def String computeID(EObject obj) {
		return null;
	}
	
}