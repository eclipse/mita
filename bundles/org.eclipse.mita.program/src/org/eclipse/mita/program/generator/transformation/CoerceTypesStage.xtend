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
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.base.expressions.util.ArgumentSorter
import org.eclipse.mita.base.expressions.FeatureCallWithoutFeature
import org.eclipse.mita.base.types.TypesFactory

class CoerceTypesStage extends AbstractTransformationStage {
	
	@Inject IConstraintFactory constraintFactory
	@Inject GeneratorUtils generatorUtils
	
	override getOrder() {
		return ORDER_VERY_EARLY;
	}
	
	def explicitlyConvertAll(EObject obj) {
		return #[Argument, ReturnStatement].exists[it.isAssignableFrom(obj.class)]
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
		
		program.eAllContents.filter[explicitlyConvertAll].forEach[it.doTransform];
		
		return program;
	}
		
	dispatch def doTransform(Argument a) {
		val functionCall = a.eContainer;
		if(functionCall instanceof ElementReferenceExpression) {
			val function = functionCall.reference;
			if(function instanceof Operation) {
				val parameters = if(functionCall instanceof FeatureCallWithoutFeature) {
					function.parameters.tail;
				}
				else {
					function.parameters;	
				}
				val argIndex = ModelUtils.getSortedArguments(parameters, functionCall.arguments).toList.indexOf(a);
				val parameter = parameters.get(argIndex);
				val pType = BaseUtils.getType(parameter.getOrigin);
				val eType = BaseUtils.getType(a.getOrigin);
				
				if(!(eType instanceof TypeVariable) && !(pType instanceof TypeVariable) && eType != pType) {
					val coercion = TypesFactory.eINSTANCE.createCoercionExpression;
					if(pType === null) {
						return;
					}
					coercion.typeSpecifier = pType;
					val inner = a.value;
					a.value = coercion;
					coercion.value = inner;
					
				}
			}
		}
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
			val coercion = TypesFactory.eINSTANCE.createCoercionExpression;
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
			val coercion = TypesFactory.eINSTANCE.createCoercionExpression; 
			expr.replaceWith(coercion)
			coercion.value = expr;
			coercion.typeSpecifier = pType;
		}
	}
	
	override protected _doTransform(EObject obj) {
		return;
	}
	
}