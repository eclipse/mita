package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.infra.SubtypeChecker
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem

interface LiteralTypeExpression<T> {
	def AbstractType getTypeOf();
	def T eval();
	def LiteralTypeExpression<T> simplify();	
	def Pair<PrimitiveLiteralType<T>, Iterable<CompositeLiteralType<T>>> decompose();
}

interface PrimitiveLiteralType<T> extends LiteralTypeExpression<T> {
	
}

interface CompositeLiteralType<T> extends LiteralTypeExpression<T> {
	
}
