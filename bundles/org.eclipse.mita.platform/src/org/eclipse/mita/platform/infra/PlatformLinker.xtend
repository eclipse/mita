package org.eclipse.mita.platform.infra

import org.eclipse.emf.ecore.EClass
import org.eclipse.mita.base.typesystem.infra.MitaTypeLinker
import org.eclipse.mita.platform.PlatformPackage
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.diagnostics.IDiagnosticProducer
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.xtext.nodemodel.INode
import org.eclipse.xtext.CrossReference
import java.util.Set
import org.eclipse.emf.ecore.EReference

class PlatformLinker extends MitaTypeLinker {
		
	override shouldLink(EClass classifier) {
		super.shouldLink(classifier) || PlatformPackage.eINSTANCE.abstractSystemResource.isSuperTypeOf(classifier);
	}
	
	override ensureIsLinked(EObject obj, INode node, CrossReference ref, Set<EReference> handledReferences, IDiagnosticProducer producer) {	
		if(node?.text == "BMA280") {
			print("")
		}
		super.ensureIsLinked(obj, node, ref, handledReferences, producer)
	}
	
}