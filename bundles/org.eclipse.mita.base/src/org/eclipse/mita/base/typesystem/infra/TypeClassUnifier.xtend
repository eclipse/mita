package org.eclipse.mita.base.typesystem.infra

import java.util.HashMap
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractBaseType
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeScheme
import org.eclipse.mita.base.typesystem.types.TypeVariable
import java.util.Set
import org.eclipse.mita.base.util.BaseUtils
import static extension org.eclipse.mita.base.util.BaseUtils.zip;
import static extension org.eclipse.mita.base.util.BaseUtils.transpose;

class TypeClassUnifier {
	public static val TypeClassUnifier INSTANCE = new TypeClassUnifier();
	
	val ClassTree<AbstractType> typeHierarchy;
	val Iterable<Class<? extends AbstractType>> typeOrder;
	
	protected new() {
		typeHierarchy = #[AbstractBaseType, /* AbstractType,*/ /*AtomicType, BaseKind, BottomType, FloatingType,*/ FunctionType, /*IntegerType, NumericType,*/ ProdType, SumType, TypeConstructorType, /*TypeHole, TypeScheme,*/ TypeVariable/*, UnorderedArguments*/]
			.fold(new ClassTree<AbstractType>(AbstractType), [t, c |
				t.add(c);
			])
		
		typeOrder = typeHierarchy.postOrderTraversal;
	}
	
//	fst :: (String, i32) -> String
//	fst :: (i8, i32) -> i8
	def TypeClass unifyTypeClassInstancesStructure(ConstraintSystem system, TypeClass typeClass) {
		val instances = typeClass.instances.keySet;
		// commonStructure: fst :: (a, b) -> c
		val commonStructure = unifyTypeClassInstancesStructure(system, instances);
		val commonType = unifyTypeClassInstancesTypes(system, commonStructure, instances);
		return new TypeClass(typeClass.instances, commonType);
	}
	
	def AbstractType unifyTypeClassInstancesTypes(ConstraintSystem system, AbstractType commonTypeStructure, Set<AbstractType> instances) {
		// find out that fst :: (a, i32) -> c
		val structure = commonTypeStructure.quote();
		val quotedInstances = instances.map[quoteLike(structure)];
		
		val commonTypesAcross = unifyTypeClassInstancesWithCommonTypesAcross(structure, quotedInstances);
		return null;
	}
	
	def Tree<AbstractType> unifyTypeClassInstancesWithCommonTypesAcross(Tree<AbstractType> commonTypeStructure, Iterable<Tree<AbstractType>> instances) {
		val result = new Tree(
			if(instances.map[it.node].groupBy[it].size == 1) {
				instances.head.node
			}
			else {				
				commonTypeStructure.node	
			}
		);
		
		result.children += commonTypeStructure.children.zip(instances.map[it.children].transpose).map[unifyTypeClassInstancesWithCommonTypesAcross(it.key, it.value)]
		return result;
	}
	
	def AbstractType unifyTypeClassInstancesStructure(ConstraintSystem system, Iterable<AbstractType> _instances) {
		val instances = _instances.map[
			if(it instanceof TypeScheme) {
				it.instantiate(system).value;
			}
			else {
				it;
			}
		]
		
		val commonType = typeOrder.findFirst[typeClazz | 
			instances.forall[typeClazz.isAssignableFrom(it.getClass)]
		]
				
		val m = commonType.getMethod("unify", ConstraintSystem, Iterable);
		val result = m.invoke(null, system, instances);
		
		return result as AbstractType;
	}
		
}
