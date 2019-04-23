package org.eclipse.mita.base.typesystem.types

import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.mita.base.typesystem.infra.Tree
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import static extension org.eclipse.mita.base.util.BaseUtils.force
import static extension org.eclipse.mita.base.util.BaseUtils.zip

@EqualsHashCode
@Accessors
@FinalFieldsConstructor
class TypeAlias extends AbstractType {
	val AbstractType aliasOf
	
	override map((AbstractType)=>AbstractType f) {
		val newAlias = aliasOf.map(f);
		if(newAlias !== aliasOf) {
			return new TypeAlias(origin, name, newAlias);
		}
		return this;
	}
	
	override quote() {
		val result = new Tree<AbstractType>(this);
		result.children += aliasOf.quote();
		return result;
	}
	
	override quoteLike(Tree<AbstractType> structure) {
		val result = new Tree<AbstractType>(this);
		result.children += #[aliasOf].zip(structure.children).map[it.key.quoteLike(it.value)]
		return result;
	}
	
	override unquote(Iterable<Tree<AbstractType>> children) {
		val alias = children.map[it.node.unquote(it.children)].head;
		return new TypeAlias(origin, alias.name, alias);
	}
	
	override getFreeVars() {
		return aliasOf.freeVars
	}
	
	override toString() {
		return ('''«name»''').toString // ~ «aliasOf»;
	}
	
	override toGraphviz() {
		return toString;
	}
	
}