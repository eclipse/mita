package org.eclipse.mita.base.typesystem.infra

import java.util.Set
import org.eclipse.emf.ecore.EClass
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
import org.eclipse.xtext.CrossReference
import org.eclipse.xtext.diagnostics.IDiagnosticProducer
import org.eclipse.xtext.linking.impl.Linker
import org.eclipse.xtext.nodemodel.INode
import org.eclipse.mita.base.types.TypesPackage
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.mita.base.types.TypeConstructor

class MitaTypeLinker extends Linker {
	
	override ensureIsLinked(EObject obj, INode node, CrossReference ref, Set<EReference> handledReferences, IDiagnosticProducer producer) {
		val classifier = ref.type?.classifier;
		if(classifier instanceof EClass) {
			if(TypesPackage.eINSTANCE.type.isSuperTypeOf(classifier)) {
				super.ensureIsLinked(obj, node, ref, handledReferences, producer);
				val txt = NodeModelUtils.getTokenText(node);
				println(txt);
				println('''Linking types: «obj.eResource?.URI.lastSegment»: «NodeModelUtils.getTokenText(node)» on («obj.eClass?.name»)«obj»''');
			}
		}
	}
	
	override protected clearReferences(EObject obj) {
		if(obj instanceof TypeConstructor || EcoreUtil2.getContainerOfType(obj, TypeConstructor) !== null) {
			return;
		}
		super.clearReferences(obj)
	}
	
}