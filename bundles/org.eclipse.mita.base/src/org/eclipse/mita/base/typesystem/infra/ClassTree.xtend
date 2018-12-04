package org.eclipse.mita.base.typesystem.infra

import java.util.ArrayList
import java.util.List
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

import static extension org.eclipse.mita.base.util.BaseUtils.force;

// can only handle classes that don't implement interfaces (since the class hierarchy with interfaces is a graph and we only check for assignable, which uses interfaces, too).
// if needed instead of using isAssignableFrom you can walk supertypes.
class ClassTree<T> {
	static val String INDENT = "  ";
		
	val Class<? extends T> node;
	var ArrayList<ClassTree<T>> children = new ArrayList;
	
	new(Class<? extends T> node) {
		this.node = node;
	}
	
	def ClassTree<T> add(Class<? extends T> c) {
		return this.merge(new ClassTree(c));
	}
	
	def ClassTree<T> merge(ClassTree<T> c) {
		// c is superType of this
		if(c.node.isAssignableFrom(node)) {
			return c.merge(this);
		}
		// this is superType of c
		else {
			// there is a superType of c in children
			// since the class hierarchy is a tree there one of those, and no children is a subtype of c
			val superOfNewNode = children.findFirst[it.node.isAssignableFrom(c.node)]
			if(superOfNewNode !== null) {
				superOfNewNode.merge(c);
			}
			// otherwise there is at least one node that is a subtype of c. find them all and add them all to c
			else {
				val subtypes = children.filter[c.node.isAssignableFrom(it.node)].force;
				val independent = (#[c] + children.filter[!subtypes.contains(it)]).force as ArrayList<ClassTree<T>>;
				children = independent;
				subtypes.forEach[
					c.merge(it);
				]
			}
			return this;
		}
	}
	
	def Iterable<Class<? extends T>> postOrderTraversal() {
		return children.flatMap[postOrderTraversal] + #[node]
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
		sb.append(node.simpleName);
		sb.append("\n");
		val indentCount2 = indentCount + 1;
		children.forEach[
			it.toString(sb, indentCount2);
		]
		
	}
	
	
	@FinalFieldsConstructor
	public static class Node<T> {
		public val int idx;
		public val T t;
	}
}