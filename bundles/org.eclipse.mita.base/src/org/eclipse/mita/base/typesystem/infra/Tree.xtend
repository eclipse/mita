package org.eclipse.mita.base.typesystem.infra

import java.util.ArrayList
import org.eclipse.xtend.lib.annotations.Accessors
import java.util.Iterator
import com.google.common.collect.Iterables
import java.util.Collections
import org.eclipse.mita.base.typesystem.types.AbstractType
import java.util.List

@Accessors
class Tree<T> {
	static val String INDENT = "  ";
	
	protected var T node;
	protected var ArrayList<Tree<T>> children = new ArrayList;
	
	new(T node) {
		this.node = node;
	}
	
	static def <T> Tree<T> copy(Tree<T> other) {
		val result = new Tree(other.node);
		result.children += other.children.map[copy(it)];
		return result;
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
		sb.append(node?.nodeToString);
		sb.append("\n");
		val indentCount2 = indentCount + 1;
		children.forEach[
			it.toString(sb, indentCount2);
		]
	}
	
	protected def String nodeToString(T node) {
		return node.toString;
	}
	
	def Iterable<T> toIterable() {
		return toPathIterable.map[it.value];
	}
	
	def Iterable<Pair<Iterable<Integer>, T>> toPathIterable() {
		// xtend's type checker fails here with #[] instead of collections.emptylist
		return #[Collections.EMPTY_LIST -> node] + children.indexed.flatMap[i_n | i_n.value.toPathIterable.map[(#[i_n.key] + it.key) -> it.value]]
	}
	
	def T get(Iterable<Integer> path) {
		if(path.empty) {
			return node;
		}
		return children.get(path.head).get(path.tail);
	}
	
	def void set(Iterable<Integer> path, T newValue) {
		if(path.empty) {
			node = newValue;
		}
		else {
			children.get(path.head).set(path.tail, newValue);
		}
	}
	
	def Iterable<Iterable<Integer>> findAll(T t) {
		val thisPath = if(node == t) {
			#[#[]]
		}
		else {
			#[]
		}
		return thisPath + children.indexed.flatMap[i_t | i_t.value.findAll(t).map[#[i_t.key] + it]]
	}
	
}