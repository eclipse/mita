package org.eclipse.mita.program.generator.transformation

import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.impl.EObjectImpl
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.mita.base.expressions.Argument
import org.eclipse.mita.base.types.Expression
import org.eclipse.mita.base.types.PresentTypeSpecifier
import org.eclipse.mita.base.types.Type
import org.eclipse.mita.base.types.TypesFactory
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.infra.MitaBaseResource
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.program.ProgramFactory
import org.eclipse.mita.program.generator.internal.ProgramCopier
import org.eclipse.xtext.EcoreUtil2

class CoerceTypesStage extends AbstractTransformationStage {
	
	override getOrder() {
		return ORDER_VERY_EARLY;
	}
	
	override protected _doTransform(EObject obj) {
		if(obj.eContainer === null) {
			val resource = ProgramCopier.getOrigin(obj).eResource;
			if(resource instanceof MitaBaseResource) {
				val typingSolution = resource.latestSolution;
				val subtypeConstraints = typingSolution.constraints.constraints.filter(SubtypeConstraint);
				subtypeConstraints.forEach[
					if(it.subType != it.superType) {
						// coerce subtype to supertype
						val originExpression = it.subType.origin;
						val origin = originExpression.resolveProxyInSameResource(resource);
						if(origin !== null) {
							val expr = EcoreUtil2.getContainerOfType(origin, Expression);
							if(expr instanceof Argument) {
								// TODO
							}
							else if(expr instanceof Expression) {
//								val coercedType = it.superType.createTypeSpecifier;
//								if(coercedType !== null) {
									val coercion = ProgramFactory.eINSTANCE.createCoercionExpression; 
									expr.replaceWith(coercion)
									coercion.value = expr;
									coercion.typeSpecifier = it.superType;
//								}
							}
						}
					}
				]
					
			} 
		}
	}
	
	def PresentTypeSpecifier createTypeSpecifier(AbstractType type) {
		val origin = type.origin;
		if(origin instanceof Type) {
			return TypesFactory.eINSTANCE.createPresentTypeSpecifier => [ts |
				ts.type = origin;
				ts.typeArguments += createTypeSpecifierTypeArgs(type);
			]
		}
	}
	
	def Iterable<PresentTypeSpecifier> createTypeSpecifierTypeArgs(AbstractType type) {
		// only exactly typeConstructorTypes are types that have type args
		if(type.class == TypeConstructorType) {
			return (type as TypeConstructorType).typeArguments.map[createTypeSpecifier];
		}
		return #[];
	}
	
	def EObject resolveProxyInSameResource(EObject origin, Resource resource) {
		if(origin.eIsProxy) {
			val origin2 = if(origin instanceof EObjectImpl) {
				origin;
			}
			val objUri = resource.URI;
			val targetUri = origin2?.eProxyURI.trimFragment;
			if(objUri != targetUri) {
				return null;
			}
			return EcoreUtil.resolve(origin, resource);
		}
		if(origin.eResource != resource) {
			return null;
		}
		return origin;
	}
	
}