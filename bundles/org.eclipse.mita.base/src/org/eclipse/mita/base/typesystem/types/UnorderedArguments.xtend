package org.eclipse.mita.base.typesystem.types

import java.util.ArrayList
import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode

import static extension org.eclipse.mita.base.util.BaseUtils.force;

@EqualsHashCode
@Accessors
class UnorderedArguments extends TypeConstructorType {
	protected val List<Pair<String, AbstractType>> argParamNamesAndValueTypes = new ArrayList;
	
	new(EObject origin, String name, Iterable<Pair<String, AbstractType>> argTypes) {
		super(origin, name, argTypes.map[it.value].force)
		this.argParamNamesAndValueTypes += argTypes;
	}
	
	override map((AbstractType)=>AbstractType f) {
		return new UnorderedArguments(origin, name, argParamNamesAndValueTypes.map[it.key -> it.value.map(f)]);
	}
	
	override getFreeVars() {
		return argParamNamesAndValueTypes.flatMap[it.value.freeVars];
	}
	
	override toGraphviz() {
		return "";
	}
	
	override void expand(ConstraintSystem system, Substitution s, TypeVariable tv) {
		val newParamAndValueTypes = argParamNamesAndValueTypes.map[ it.key -> system.newTypeVariable(it.value.origin) as AbstractType ].force;
		val newType = new UnorderedArguments(origin, name, newParamAndValueTypes);
		s.add(tv, newType);
	}
}