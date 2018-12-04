package org.eclipse.mita.base.typesystem.infra

import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractBaseType
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.BaseKind
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.typesystem.types.FloatingType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.IntegerType
import org.eclipse.mita.base.typesystem.types.NumericType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeHole
import org.eclipse.mita.base.typesystem.types.TypeScheme
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.typesystem.types.UnorderedArguments

class TypeClassUnifier {
	public static val TypeClassUnifier INSTANCE = new TypeClassUnifier();
	
	val ClassTree<AbstractType> typeHierarchy;
	val Iterable<Class<? extends AbstractType>> typeOrder;
	
	protected new() {
		typeHierarchy = #[AbstractBaseType, /* AbstractType ,*/ AtomicType, BaseKind, BottomType, FloatingType, FunctionType, IntegerType, NumericType, ProdType, SumType, TypeConstructorType, TypeHole, TypeScheme, TypeVariable, UnorderedArguments]
			.fold(new ClassTree<AbstractType>(AbstractType), [t, c |
				t.add(c);
			])
		
		typeOrder = typeHierarchy.postOrderTraversal;
	}
	
	def TypeClass unifyTypeClassInstances(ConstraintSystem system, TypeClass typeClass) {
		return new TypeClass(typeClass.instances, unifyTypeClassInstances(system, typeClass.instances.keySet));
	}
	
	def AbstractType unifyTypeClassInstances(ConstraintSystem system, Iterable<AbstractType> _instances) {
		val instances = _instances.map[
			if(it instanceof TypeScheme) {
				it.instantiate(system).value;
			}
			else {
				it;
			}
		]
		
		
		return null;
	}
}
