package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject
import static extension org.eclipse.mita.base.util.BaseUtils.force;
import static extension org.eclipse.mita.base.util.BaseUtils.zip;
import org.eclipse.mita.base.typesystem.infra.Tree
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.base.typesystem.infra.TypeClassUnifier
import org.eclipse.mita.base.types.Variance

class NumericAddType extends TypeConstructorType implements LiteralTypeExpression<Long> {
	static def unify(ConstraintSystem system, Iterable<AbstractType> instances) {
		// if not all sum types have the same number of arguments, return a new TV
		if(instances.map[it as TypeConstructorType].map[it.typeArguments.size].groupBy[it].size > 1) {
			return system.newTypeVariable(null);
		}
		// else transpose the instances' type args (so we have a list of all the first args, all the second args, etc.), then unify each of those
		val typeArgs = BaseUtils.transpose(instances.map[it as TypeConstructorType].map[it.typeArguments])
				.map[TypeClassUnifier.INSTANCE.unifyTypeClassInstancesStructure(system, it)]
				.force;
		val name = typeArgs.head.name;
		return new NumericAddType(null, name, typeArgs.map[it -> Variance.UNKNOWN]);
	}
	
	
	new(EObject origin, String name, Iterable<Pair<AbstractType, Variance>> typeArguments) {
		super(origin, name, typeArguments)
	}
	
//	override eval() {
//		val maybeResults = (simplify() as NumericAddType).typeArguments;
//		if(maybeResults.size === 1) {
//			val maybeResult = maybeResults.head;
//			if(maybeResult instanceof LiteralNumberType) {
//				return maybeResult.value;
//			}
//		}
//		
//		return -1L;
//	}
//	
//	override simplify() {
//		val simpleNumbers = typeArguments.filter(LiteralNumberType).force;
//		val simplifiedValue = simpleNumbers.fold(0L, [t, v| v.eval + t]);            // TODO actually put in a type here ---------\/
//		val simplification =  new LiteralNumberType(simpleNumbers.head.origin, String.valueOf(simplifiedValue), simplifiedValue, null);
//		return new NumericAddType(origin, name, typeArguments.filter[!(it instanceof LiteralNumberType)] + #[simplification]);
//	}
	
	override map((AbstractType)=>AbstractType f) {
		val newTypeArgs = typeArguments.map[ it.map(f) ].force;
		if(typeArguments.zip(newTypeArgs).exists[it.key !== it.value]) {
			return new NumericAddType(origin, name, newTypeArgs.zip(typeArgumentsAndVariances.map[it.value]));
		}
		return this;
	}
	
	override unquote(Iterable<Tree<AbstractType>> children) {
		return new NumericAddType(origin, name, children.map[it.node.unquote(it.children)].zip(typeArgumentsAndVariances.map[it.value]));
	}
	
	override void expand(ConstraintSystem system, Substitution s, TypeVariable tv) {
		val newTypeVars = typeArguments.map[ system.newTypeVariable(it.origin) as AbstractType ].zip(typeArgumentsAndVariances.map[it.value]);
		val newCType = new NumericAddType(origin, name, newTypeVars);
		s.add(tv, newCType);
	}
	
	override toString() {
		return '''(«typeArguments.join(" + ")»)'''
	}
	
}