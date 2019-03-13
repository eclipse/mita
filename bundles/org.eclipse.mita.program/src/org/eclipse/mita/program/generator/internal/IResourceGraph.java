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

package org.eclipse.mita.program.generator.internal;

import org.eclipse.xtext.xbase.lib.Pair;

/**
 * The resource graph is the graph where the nodes represent all system resources used by a PAX program.
 * The edges of this graph denote a "depends on" relationship which implies that, if A -> B, then B needs
 * to be initialized/enabled before A.
 * 
 * Note: at the moment this resource graph just naively maps to system resources, but in the future might
 * 		 encompass more elaborate resource planning schemes related to scarse resources, such as timer,
 * 		 hardware blocks or ISRs.
 *
 */
public interface IResourceGraph<T> {

	/**
	 * @return the list of all nodes in this graph
	 */
	Iterable<T> getNodes();
	
	/**
	 * @return this list of all edges in this graph in the form {@link Pair#getKey()} -&gt; {@link Pair#getValue()}.
	 */
	Iterable<Pair<String, String>> getEdges();
	
	/**
	 * @return true if this graph is a directed acyclic graph
	 */
	boolean isDAG();
	
	/**
	 * @return all nodes of this graph in their topological sort order
	 */
	Iterable<T> getNodesInTopologicalOrder();
	
}
