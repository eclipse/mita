package org.eclipse.mita.base.typesystem.infra

import org.eclipse.mita.base.typesystem.solver.ConstraintSolution
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.linking.lazy.LazyLinkingResource
import java.io.InputStream
import java.util.Map
import java.io.IOException
import org.eclipse.mita.base.types.GeneratedElement
import org.eclipse.mita.base.types.GeneratedObject

//class MitaBaseResource extends XtextResource {
class MitaBaseResource extends LazyLinkingResource {
	@Accessors
	protected ConstraintSolution latestSolution;	
}
