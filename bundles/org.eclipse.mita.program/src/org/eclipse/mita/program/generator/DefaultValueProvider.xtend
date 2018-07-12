package org.eclipse.mita.program.generator

import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.Expression
import org.eclipse.mita.base.expressions.ExpressionsFactory
import org.eclipse.mita.base.expressions.ExpressionsPackage
import org.eclipse.mita.base.expressions.PrimitiveValueExpression
import org.eclipse.mita.base.types.AnonymousProductType
import org.eclipse.mita.base.types.ComplexType
import org.eclipse.mita.base.types.EnumerationType
import org.eclipse.mita.base.types.GeneratedType
import org.eclipse.mita.base.types.PrimitiveType
import org.eclipse.mita.base.types.Singleton
import org.eclipse.mita.base.types.StructureType
import org.eclipse.mita.base.types.SumType
import org.eclipse.mita.base.types.Type
import org.eclipse.mita.base.types.typesystem.GenericTypeSystem
import org.eclipse.mita.base.types.typesystem.ITypeSystem
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.program.ProgramPackage
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.scoping.IScopeProvider
import org.eclipse.xtext.scoping.impl.FilteringScope

class DefaultValueProvider {
	
	@Inject 
	ITypeSystem typeSystem;
	
	@Inject
	protected IScopeProvider scopeProvider;
	
	def dispatch dummyExpression(Type itemType, EObject context) {
		// fall-back, just print a default text
		createDummyString
	}
	
	def dispatch dummyExpression(PrimitiveType itemType, EObject context) {
		if (typeSystem.isSuperType(itemType, typeSystem.getType(GenericTypeSystem.INTEGER))) {
			createDummyInteger
		} else if (typeSystem.isSuperType(itemType, typeSystem.getType(GenericTypeSystem.STRING))) {
			createDummyString
		} else if (typeSystem.isSuperType(itemType, typeSystem.getType(GenericTypeSystem.BOOLEAN))) {
			createDummyBool
		} else {
			createDummyString
		}
	}
	
	def PrimitiveValueExpression createDummyString() {
		return ExpressionsFactory.eINSTANCE.createPrimitiveValueExpression => [
			value = ExpressionsFactory.eINSTANCE.createStringLiteral => [
				value = 'replace_me'
			]
		]
	}
	
	def PrimitiveValueExpression createDummyInteger() {
		return ExpressionsFactory.eINSTANCE.createPrimitiveValueExpression => [
			value = ExpressionsFactory.eINSTANCE.createIntLiteral => [
				value = 0
			]
		]
	}
	
	def PrimitiveValueExpression createDummyBool() {
		return ExpressionsFactory.eINSTANCE.createPrimitiveValueExpression => [
			value = ExpressionsFactory.eINSTANCE.createBoolLiteral => [
				value = true
			]
		]
	}

	def dispatch Expression dummyExpression(EnumerationType itemType, EObject context) {
		if (!itemType.enumerator.isEmpty) {
			return ExpressionsFactory.eINSTANCE.createElementReferenceExpression => [
				reference = itemType.enumerator.head
			]
		}
		return createDummyString
	}
	def dispatch Expression dummyExpression(StructureType itemType, EObject context) {
		val args = itemType.parameters.map[p | ExpressionsFactory.eINSTANCE.createArgument => [
			 value = p.type.dummyExpression(context)
		]];
		
		return ExpressionsFactory.eINSTANCE.createElementReferenceExpression => [
			reference = itemType;
			operationCall = true;
			arguments += args;
		]
			
	}
	def dispatch Expression dummyExpression(SumType itemType, EObject context) {
		if (!itemType.alternatives.isEmpty) {
			val alt = itemType.alternatives.head;
			val args = alt.accessorsTypes.map[tp | ExpressionsFactory.eINSTANCE.createArgument => [
				 value = tp.dummyExpression(context)
			]];
			if(EcoreUtil2.getContainerOfType(context, SystemResourceSetup) === null) {
				return ExpressionsFactory.eINSTANCE.createFeatureCall => [
					feature = alt;
					operationCall = true;
					owner = ExpressionsFactory.eINSTANCE.createElementReferenceExpression => [
						reference = itemType;
					]
					arguments += args;
				]
			}
			return ExpressionsFactory.eINSTANCE.createElementReferenceExpression => [
				reference = itemType.alternatives.head;
				operationCall = true;
				arguments += args;
			]
			
		}
		return createDummyString
	}

	def dispatch dummyExpression(AbstractSystemResource itemType, EObject context) {
		val scope = getSetupScope(itemType, context);
		if (!scope.allElements.empty) {
			return ExpressionsFactory.eINSTANCE.createElementReferenceExpression => [
				reference = scope.allElements.head.EObjectOrProxy
			]
		}
		return createDummyString
	}
	
	protected def FilteringScope getSetupScope(AbstractSystemResource itemType, EObject context) {
		new FilteringScope(
			scopeProvider.getScope(context, ExpressionsPackage.Literals.ELEMENT_REFERENCE_EXPRESSION__REFERENCE),
			[
				ProgramPackage.Literals.SYSTEM_RESOURCE_SETUP.isSuperTypeOf(it.EClass) &&
					(it.EObjectOrProxy as SystemResourceSetup).type == itemType
			]
		)
	}
	
	def String getDummyConstructor(String base, ComplexType typ) {
		val namedParamsOpt = ModelUtils.getAccessorParameters(typ);
		if(namedParamsOpt.present) {
			val namedParams = namedParamsOpt.get
			val proposalString = '''«base»«typ.name»(«FOR param : namedParams SEPARATOR(", ")»«param.name» = «getDummyString(param.type)»«ENDFOR»)'''
			return proposalString;
		}
		if(typ instanceof AnonymousProductType) {
			val proposalString = '''«base»«typ.name»(«FOR conType : typ.accessorsTypes SEPARATOR(", ")»«getDummyString(conType)»«ENDFOR»)'''
			return proposalString;
		}
		if(typ instanceof Singleton) {
			return '''«base»«typ.name»()'''
		}
		return null;
	}
	
	def String getDummyString(Type obj) {
		if(obj instanceof ComplexType) {
			if(obj instanceof SumType) {
				if(obj.alternatives.empty) {
					return '';
				}
				return getDummyConstructor(obj.name + '.', obj.alternatives.head);
			}
			return getDummyConstructor('', obj);
		}
		if(obj instanceof GeneratedType) {
			if (typeSystem.isSuperType(obj, typeSystem.getType(GenericTypeSystem.STRING))) {
				return '""';
			}
			if (typeSystem.isSuperType(obj, typeSystem.getType(GenericTypeSystem.OPTIONAL))) {
				return 'none()';
			}
			if (typeSystem.isSuperType(obj, typeSystem.getType(GenericTypeSystem.ARRAY))) {
				return '[]';
			}
			return '';
		}
		if(obj instanceof PrimitiveType) {
			if (typeSystem.isSuperType(obj, typeSystem.getType(GenericTypeSystem.INTEGER))) {
				return '0';
			} else if (typeSystem.isSuperType(obj, typeSystem.getType(GenericTypeSystem.BOOLEAN))) {
				return 'false';
			}
		}
		return '';
	}
	
}