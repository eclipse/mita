package org.eclipse.mita.base.typesystem.infra

import java.util.ArrayList
import java.util.List
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

import static extension org.eclipse.mita.base.util.BaseUtils.force;

// can only handle classes that don't implement interfaces (since the class hierarchy with interfaces is a graph and we only check for assignable, which uses interfaces, too).
// if needed instead of using isAssignableFrom you can walk supertypes.
class ClassTree<T> extends Tree<Class<? extends T>> {
	
	new(Class<? extends T> node) {
		super(node)
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
			val superOfNewNode = children.findFirst[it.node.isAssignableFrom(c.node)] as ClassTree<T>;
			if(superOfNewNode !== null) {
				superOfNewNode.merge(c);
			}
			// otherwise there is at least one node that is a subtype of c. find them all and add them all to c
			else {
				val subtypes = children.filter[c.node.isAssignableFrom(it.node)].map[it as ClassTree<T>].force;
				val independent = (#[c] + children.filter[!subtypes.contains(it)]).force as ArrayList<Tree<Class<? extends T>>>;
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
	
	override protected nodeToString(Class<? extends T> node) {
		return node.simpleName
	}
	
}