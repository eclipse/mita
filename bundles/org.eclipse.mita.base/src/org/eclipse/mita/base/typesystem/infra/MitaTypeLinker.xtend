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

class MitaTypeLinker extends Linker {
	
	override ensureIsLinked(EObject obj, INode node, CrossReference ref, Set<EReference> handledReferences, IDiagnosticProducer producer) {
		val classifier = ref.type?.classifier;
		if(classifier instanceof EClass) {
			if(TypesPackage.eINSTANCE.type.isSuperTypeOf(classifier)) {
				println('''Linking types: «obj.eResource»:«obj» from «node»''');
				super.ensureIsLinked(obj, node, ref, handledReferences, producer);
			}
		}
	}
	
}