package org.eclipse.mita.program.generator.transformation

import org.eclipse.mita.base.expressions.Argument
import org.eclipse.mita.base.types.Expression
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.program.ProgramFactory
import org.eclipse.mita.program.ReturnStatement
import org.eclipse.xtext.EcoreUtil2

import static extension org.eclipse.mita.program.generator.internal.ProgramCopier.getOrigin
import org.eclipse.mita.base.expressions.PostFixUnaryExpression
import org.eclipse.mita.base.expressions.UnaryExpression

class CoerceTypesStage extends AbstractTransformationStage {
	
	override getOrder() {
		return ORDER_VERY_EARLY;
	}
	
	dispatch def doTransform(Expression e) {
		var exp = e;
		exp.transformChildren;
		var eType = BaseUtils.getType(exp.getOrigin);
		var parent = exp.eContainer;
		val pType = BaseUtils.getType(parent.getOrigin);
		if(parent instanceof PostFixUnaryExpression) {
			exp = parent;
			parent = parent.eContainer;
		}
		if(!(eType instanceof TypeVariable) && !(pType instanceof TypeVariable) && eType != pType) {
			val coercion = ProgramFactory.eINSTANCE.createCoercionExpression;
			if(pType === null) {
				return;
			}
			coercion.typeSpecifier = pType;
			 if(exp instanceof Argument) {
				val inner = exp.value;
				exp.value = coercion;
				coercion.value = inner;
			}
			else {
				exp.replaceWith(coercion)
				coercion.value = exp;
			}
		}
	}
	
	dispatch def doTransform(ReturnStatement stmt) {
		stmt.transformChildren;
		val expr = stmt.value;
		val eType = BaseUtils.getType(expr.getOrigin);
		val parent = EcoreUtil2.getContainerOfType(stmt, Operation);
		val pType = BaseUtils.getType(parent.typeSpecifier.getOrigin);
		if(!(eType instanceof TypeVariable) && !(pType instanceof TypeVariable) && eType != pType) {
			val coercion = ProgramFactory.eINSTANCE.createCoercionExpression; 
			expr.replaceWith(coercion)
			coercion.value = expr;
			coercion.typeSpecifier = pType;
		}
	}	
}