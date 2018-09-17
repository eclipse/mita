package org.eclipse.mita.base.typesystem.infra

import java.util.Set
import org.eclipse.emf.ecore.EClass
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
import org.eclipse.mita.base.types.TypesPackage
import org.eclipse.xtext.CrossReference
import org.eclipse.xtext.diagnostics.IDiagnosticProducer
import org.eclipse.xtext.linking.impl.Linker
import org.eclipse.xtext.nodemodel.INode
import org.eclipse.xtext.nodemodel.util.NodeModelUtils

class MitaTypeLinker extends Linker {
	
	def boolean shouldLink(EClass classifier) {
		return TypesPackage.eINSTANCE.type.isSuperTypeOf(classifier);
	}
	
	override ensureIsLinked(EObject obj, INode node, CrossReference ref, Set<EReference> handledReferences, IDiagnosticProducer producer) {
		val classifier = ref.type?.classifier;
		if(classifier instanceof EClass) {
			if(shouldLink(classifier)) {
				super.ensureIsLinked(obj, node, ref, handledReferences, producer);
				val txt = NodeModelUtils.getTokenText(node);
//				println(txt);
				//println('''Linking types: «obj.eResource?.URI.lastSegment»: «NodeModelUtils.getTokenText(node)» on («obj.eClass?.name»)«obj»''');
			}
		}
	}
	
	override protected clearReference(EObject obj, EReference ref) {
		return;
//		if(shouldNotClearReference(obj, ref)) {
//			return;
//		}
//		super.clearReference(obj, ref)
	}
	
	override protected isNullValidResult(EObject obj, EReference eRef, INode node) {
		return true;
	}
	
	def shouldNotClearReference(EObject object, EReference reference) {
		return reference.eClass == TypesPackage.eINSTANCE.type || reference.eClass == TypesPackage.eINSTANCE.event;
	}
	
	override protected clearReferences(EObject obj) {
		
		super.clearReferences(obj)
	}
	
}