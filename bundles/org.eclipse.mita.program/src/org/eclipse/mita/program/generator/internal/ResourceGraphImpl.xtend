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

class ResourceGraphImpl<T> implements IResourceGraph<T> {
	
	protected final Iterable<Pair<String, String>> edges;
	
	/**
	 * The nodes of this graph. If this graph is a DAG these nodes are expected to be in topological order
	 */
	protected final Iterable<T> nodes;
	
	protected final boolean isDag;
	
	new(Iterable<T> nodes, Iterable<Pair<String, String>> edges, boolean isDAG) {
		this.nodes = nodes;
		this.edges = edges;
		this.isDag = isDAG;
	}
	
	override getEdges() {
		return edges;
	}
	
	override getNodes() {
		return nodes;
	}
	
	override getNodesInTopologicalOrder() {
		return if(isDag) nodes else #[];
	}
	
	override isDAG() {
		return isDag;
	}
	
}