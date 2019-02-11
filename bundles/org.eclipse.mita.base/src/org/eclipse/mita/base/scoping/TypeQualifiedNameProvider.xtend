package org.eclipse.mita.base.scoping

import org.eclipse.mita.base.types.SumAlternative
import org.eclipse.mita.base.types.SumSubTypeConstructor
import org.eclipse.xtext.naming.QualifiedName

class TypeQualifiedNameProvider extends BaseQualifiedNameProvider {
	dispatch def doGetFullyQualifiedName(SumSubTypeConstructor f) {
		val sumAlt = f.eContainer as SumAlternative;
		val sumType = sumAlt.eContainer;
		val pkg = sumType.eContainer;
		
		val baseQID = pkg?.fullyQualifiedName;
		val autoQID = if(baseQID === null) {
			QualifiedName.create("<auto>");
		}
		else {
			baseQID.append("<auto>");
		}
		
		return autoQID.append(sumAlt.name);
	}
	
	dispatch def doGetFullyQualifiedName(SumAlternative sumAlt) {
		val sumType = sumAlt.eContainer;
		val pkg = sumType.eContainer;
		
		val baseQID = pkg?.fullyQualifiedName;
		val autoQID = if(baseQID === null) {
			QualifiedName.create("<auto>");
		}
		else {
			baseQID.append("<auto>");
		}
		
		return autoQID.append(sumAlt.name);
	}
}