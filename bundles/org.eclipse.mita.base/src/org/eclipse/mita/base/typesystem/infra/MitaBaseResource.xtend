package org.eclipse.mita.base.typesystem.infra

import org.eclipse.mita.base.typesystem.solver.ConstraintSolution
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.linking.lazy.LazyLinkingResource
import org.eclipse.xtext.util.CancelIndicator

//class MitaBaseResource extends XtextResource {
class MitaBaseResource extends LazyLinkingResource {
	@Accessors
	protected ConstraintSolution latestSolution;
	@Accessors	
	protected MitaCancelInidicator cancelIndicator;

	new() {
		super();
		mkCancelIndicator();
	}
	
	def MitaCancelInidicator mkCancelIndicator() {
		cancelIndicator = new MitaCancelInidicator();
		return cancelIndicator;
	}
	
	static class MitaCancelInidicator implements CancelIndicator {
		public boolean canceled = false;
		override isCanceled() {
			return canceled;
		}
	}
}
