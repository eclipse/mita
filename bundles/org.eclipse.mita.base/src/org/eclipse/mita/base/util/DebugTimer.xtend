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
		
	public def start(String name) {
		this.traces.push(new Trace(Instant.now(), name, Thread.currentThread.id));
	}
	
	public def stop() {
		if (!this.traces.isEmpty()) {
			val prev = this.traces.pop();
			if (prev.threadID !== Thread.currentThread.id) {
				throw new Exception("timer stopped from different thread");
			}
			this.results.add(new TraceResult(Duration.between(prev.start, Instant.now()), prev.name, traces.length));
		}
	}
	
	public override toString() {
		return this.results.map[ it.toString ].join("\n")
	}
	
	@FinalFieldsConstructor
	@Accessors
	static class TraceResult {
		protected val Duration time;
		protected val String name;
		protected val int depth;
		
		public override toString() {
			val indent = newCharArrayOfSize(depth * 4);
			indent.replaceAll([' ']);
			return '''«new String(indent)»«name»: «time.toMillis()» ms''';
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

 