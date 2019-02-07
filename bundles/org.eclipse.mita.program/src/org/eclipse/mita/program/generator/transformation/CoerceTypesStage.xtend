package org.eclipse.mita.program.generator.transformation

import com.google.inject.Inject
import org.eclipse.mita.base.expressions.Argument
import org.eclipse.mita.base.expressions.PostFixUnaryExpression
import org.eclipse.mita.base.types.Expression
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.typesystem.IConstraintFactory
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.ProgramFactory
import org.eclipse.mita.program.ReturnStatement
import org.eclipse.xtext.EcoreUtil2

import static extension org.eclipse.mita.program.generator.internal.ProgramCopier.getOrigin
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.emf.ecore.EObject
import java.util.ArrayList

class CoerceTypesStage extends AbstractTransformationStage {
	
	@Inject IConstraintFactory constraintFactory
	
	override getOrder() {
		return ORDER_VERY_EARLY;
	}
	
	override transform(ITransformationPipelineInfoProvider pipeline, Program program) {
		constraintFactory.typeRegistry.isLinking = true;
		val constraints = constraintFactory.create(program).constraints.filter(SubtypeConstraint);
				
		constraints.forEach[c |
			var sub = c.subType.origin;
			var top = c.superType.origin;
			if(sub !== null && top !== null && sub.eContainer === top) {
				doTransform(sub);				
			}
		]
		
		program.eAllContents.filter(ReturnStatement).forEach[it.doTransform];
		
		return program;
	}
	
	dispatch def doTransform(Expression e) {
		var exp = e;
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
	
	override protected _doTransform(EObject obj) {
		return;
	}
	
}