package org.eclipse.mita.base.typesystem.infra

import com.google.common.collect.Multimap
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EStructuralFeature.Setting
import org.eclipse.mita.base.types.GeneratedObject
import org.eclipse.xtext.diagnostics.IDiagnosticProducer
import org.eclipse.xtext.linking.lazy.LazyLinker
import org.eclipse.xtext.nodemodel.INode

class MitaLinker extends LazyLinker {

	override protected installProxies(EObject obj, IDiagnosticProducer producer, Multimap<Setting, INode> settingsToLink) {
		super.installProxies(obj, producer, settingsToLink);
	}
	
	override protected clearReferences(EObject obj) {

	}
	
}
