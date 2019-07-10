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
import org.eclipse.mita.base.typesystem.infra.SubtypeChecker
import org.eclipse.xtend.lib.annotations.Accessors

import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull

/**
 * NumericAddType represents the addition of multiple types, for example (T + '1 + '3)
 */
@Accessors
class NumericAddType extends TypeConstructorType implements CompositeLiteralType<Long> {
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
		return new NumericAddType(null, name, typeArgs.head.castOrNull(NumericAddType)?.typeOf, typeArgs.map[it -> Variance.UNKNOWN]);
	}
	
	val AbstractType typeOf;
	
	new(EObject origin, String name, AbstractType typeOf, Iterable<Pair<AbstractType, Variance>> typeArguments) {
		super(origin, name, typeArguments)
		this.typeOf = typeOf;
	}
	
	override eval() {
		val maybeResults = simplify;
		if(maybeResults instanceof NumericAddType) {
			if(maybeResults.typeArguments.size === 1) {
				val maybeResult = maybeResults.typeArguments.head;
				if(maybeResult instanceof LiteralNumberType) {
					return maybeResult.value;
				}
			}
		}
		else if(maybeResults instanceof LiteralNumberType) {
			return maybeResults.value;
		}	
		return null;
	}
	
	override simplify() {
		val decomposition = decompose();
		if(decomposition.value.empty) {
			return decomposition.key;
		}
		return new NumericAddType(origin, name, typeOf, typeArgumentsAndVariances.filter[!(it.key instanceof LiteralNumberType)] + #[decomposition.key as AbstractType -> Variance.UNKNOWN]);
	}
	
	override decompose() {
		val simplTypeArgs = typeArguments
			.filter(LiteralTypeExpression)
			.map[simplify];
		val simpleNumbers = simplTypeArgs
			.filter(LiteralNumberType).force;
		val simplifiedValue = simpleNumbers.fold(0L, [t, v| v.eval() + t]);
		val simplification =  new LiteralNumberType(simpleNumbers.head?.origin, simplifiedValue, typeOf);
		val rest = typeArgumentsAndVariances
			.filter[!(it.key instanceof LiteralNumberType) && (it.key instanceof LiteralTypeExpression)]
			.map[(it.key as LiteralTypeExpression<Long>).simplify]
			.filter(CompositeLiteralType)
			.map[it as CompositeLiteralType<Long>];
		return simplification -> rest;
	}
	
	override map((AbstractType)=>AbstractType f) {
		val newTypeArgs = typeArguments.map[ it.map(f) ].force;
		val newTypeOf = typeOf.map(f);
		if(typeOf !== newTypeOf || typeArguments.zip(newTypeArgs).exists[it.key !== it.value]) {
			return new NumericAddType(origin, name, newTypeOf, newTypeArgs.zip(typeArgumentsAndVariances.map[it.value]));
		}
		return this;
	}
	
	override unquote(Iterable<Tree<AbstractType>> children) {
		return new NumericAddType(origin, name, typeOf, children.map[it.node.unquote(it.children)].zip(typeArgumentsAndVariances.map[it.value]));
	}
	
	override replaceProxies(ConstraintSystem system, (TypeVariableProxy)=>Iterable<AbstractType> resolve) {
		return map[it.replaceProxies(system, resolve)];
	}
	
	override void expand(ConstraintSystem system, Substitution s, TypeVariable tv) {
		val newTypeVars = typeArguments.map[ system.newTypeVariable(it.origin) as AbstractType ].zip(typeArgumentsAndVariances.map[it.value]);
		val newCType = new NumericAddType(origin, name, typeOf, newTypeVars);
		s.add(tv, newCType);
	}
	
	override toString() {
		val simpl = simplify();
		if(simpl instanceof NumericAddType) {
			return '''(«typeArguments.join(" + ")»)'''			
		}
		return simpl.toString;
	}
	
	override getTypeArgument() {
		return Long;
	}
	
}