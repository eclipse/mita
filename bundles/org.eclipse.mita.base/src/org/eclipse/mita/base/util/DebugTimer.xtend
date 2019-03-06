/********************************************************************************
 * Copyright (c) 2018, 2019 Robert Bosch GmbH & TypeFox GmbH
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Robert Bosch GmbH & TypeFox GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

package org.eclipse.mita.base.util

import java.time.Instant
import java.util.Stack
import java.util.LinkedList
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtend.lib.annotations.Accessors
import java.time.Duration

class DebugTimer {
	protected val traces = new Stack<Trace>();
	protected val results = new LinkedList<TraceResult>();
	
	boolean disable;
	
	new(boolean disable) {
		this.disable = disable;
	}
	
	public def start(String name) {
		if(disable) {
			return;
		}
		this.traces.push(new Trace(Instant.now(), name, Thread.currentThread.id));
	}
	
	public def stop(String expectedName) {
		if(disable) {
			return;
		}
		if (!this.traces.isEmpty()) {
			val prev = this.traces.pop();
			val internalPrefix = computeName(prev.name);
			this.results.add(new TraceResult(Duration.between(prev.start, Instant.now()).nano, internalPrefix, traces.length));
			
			if(prev.name != expectedName) {
				throw new Exception("different timer stopped");
			}
			if (prev.threadID !== Thread.currentThread.id) {
				throw new Exception("timer stopped from different thread");
			}
		}
	}
	
	public def getByPrefix(String prefix) {
		if(disable) {
			return #[];
		}
		return results.filter[it.name.startsWith(prefix)]
	}
	
	
	
	public def consolidateByPrefix(String prefix) {
		if(disable) {
			return;
		}
		val internalPrefix = computeName(prefix);
		val time = results.filter[it.name.startsWith(internalPrefix)].fold(0L, [i, t| i+t.timeNs]);
		results.removeIf[it.name.startsWith(internalPrefix)];
		results.add(new TraceResult(time, internalPrefix, traces.length));
	}
	
	protected def computeName(String lastSegment) {
		return (traces.map[it.name] + #[lastSegment]).join(".")
	}
	
	public override toString() {
		return this.results.map[ it.toString ].join("\n")
	}
	
	@FinalFieldsConstructor
	@Accessors
	static class TraceResult {
		protected val long timeNs;
		protected val String name;
		protected val int depth;
		
		public override toString() {
			val indent = newCharArrayOfSize(depth * 4);
			indent.replaceAll([' ']);
			return '''«new String(indent)»«name»: «timeNs/1000000» ms''';
		}
	}
	
	@FinalFieldsConstructor
	@Accessors
	static class Trace {
		protected val Instant start;
		protected val String name;
		protected val long threadID;
	}
	
}

 