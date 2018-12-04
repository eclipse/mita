package org.eclipse.mita.base.typesystem.infra

import java.util.ArrayList

class Tree<T> {
	static val String INDENT = "  ";
	
	protected val T node;
	protected var ArrayList<Tree<T>> children = new ArrayList;
	
	new(T node) {
		this.node = node;
	}
	
	override toString() {
		val sb = new StringBuilder;
		toString(sb, 0);
		return sb.toString;
	}
	
	def void toString(StringBuilder sb, int indentCount) {
		for(var i = 0; i < indentCount; i++) {
			sb.append(INDENT);
		}
		sb.append(node.nodeToString);
		sb.append("\n");
		val indentCount2 = indentCount + 1;
		children.forEach[
			it.toString(sb, indentCount2);
		]
	}
	
	protected def String nodeToString(T node) {
		return node.toString;
	}
}