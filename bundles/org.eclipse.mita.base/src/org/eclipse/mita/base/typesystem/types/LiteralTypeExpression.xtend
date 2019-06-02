package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.infra.SubtypeChecker
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem

interface LiteralTypeExpression<T> {
	def T eval(SubtypeChecker subtypeChecker, ConstraintSystem s, EObject typeResolutionOrigin);
	def LiteralTypeExpression<T> simplify(SubtypeChecker subtypeChecker, ConstraintSystem s, EObject typeResolutionOrigin);	
}