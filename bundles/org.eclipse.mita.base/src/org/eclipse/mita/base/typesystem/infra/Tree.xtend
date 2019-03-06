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

package org.eclipse.mita.base.typesystem.infra

import java.util.ArrayList
import java.util.Collections
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.xtend.lib.annotations.Accessors
import static extension org.eclipse.mita.base.util.BaseUtils.zip;

@Accessors
class Tree<T> {
	static val String INDENT = "  ";
	
	protected var T node;
	protected var ArrayList<Tree<T>> children = new ArrayList;
	
	new(T node) {
		this.node = node;
	}
	
	override equals(Object other) {
		if(other instanceof Tree) {
			return this.node == other.node 
				&& this.children.size == other.children.size 
				&& this.children.zip(other.children).fold(false, [b, t1t2 | b && t1t2.key == t1t2.value])
		}
		return false;
	}
	
	static def <T> Tree<T> copy(Tree<T> other) {
		val result = new Tree(other.node);
		result.children += other.children.map[copy(it)];
		return result;
	}
	
	def <S> Tree<Pair<T, S>> zip(Tree<S> other) {
		val result = new Tree(this.node -> other.node)
		result.children += this.children.zip(other.children).map[it.key.zip(it.value)]
		return result;
	}
	
	def <S> S fold(S seed, (S, T) => S f) {
		val sChildren = children.fold(seed, [s, t | t.fold(s, f)]);
		return f.apply(sChildren, node);
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