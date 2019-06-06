/**
 * Copyright (c) 2015 committers of YAKINDU and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 * Contributors:
 * 	committers of YAKINDU - initial API and implementation
 * 
 */
package org.eclipse.mita.base.types.validation;

import java.util.List;

import org.eclipse.core.runtime.Assert;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.EStructuralFeature;
import org.eclipse.xtend.lib.annotations.EqualsHashCode;
import org.eclipse.xtext.diagnostics.Severity;

import com.google.common.base.Predicate;
import com.google.common.collect.Iterables;
import com.google.common.collect.Lists;

/**
 * @author andreas muelder - Initial contribution and API
 * 
 */
public interface IValidationIssueAcceptor {

	@EqualsHashCode
	public static class ValidationIssue {

		private Severity severity;
		private String message;
		private String issueCode;
		private transient EObject target;
		private EStructuralFeature feature;
		
		private static boolean shouldTest() {
			return false;
		}
		private static String getTestString() {
			return "10 is not a uint32";
		}
		private static boolean testFun(String s) {
			return s.equals(getTestString());
		}
		private static void singleBreakpoint() {
			System.out.print("");
		}
		
		public ValidationIssue(Severity severity, String message, String issueCode) {
			this(severity, message, null, null, issueCode);
		}
		
		public ValidationIssue(ValidationIssue self, String newMessage) {
			this.message = newMessage;
			if(self != null) {
				this.severity = self.severity;
				this.issueCode = self.issueCode;
				this.target = self.target;
				this.feature = self.feature;
			}
			else {
				this.severity = Severity.ERROR;
				this.issueCode = "";
				this.target = null;
				this.feature = null;
			}
			if(shouldTest() && testFun(message)) {
				singleBreakpoint();
			}
		}
		
		public ValidationIssue(String message, EObject target) {
			this(Severity.ERROR, message, target, null, "");
		}
		public ValidationIssue(Severity severity, String message, EObject target) {
			this(severity, message, target, null, "");
		}
		public ValidationIssue(Severity severity, String message, EObject target, EStructuralFeature feature, String issueCode) {
			Assert.isNotNull(message);
			Assert.isNotNull(issueCode);
			Assert.isNotNull(severity);
			this.severity = severity;
			this.message = message;
			this.target = target;
			this.issueCode = issueCode;
			this.feature = feature;
			if(shouldTest() && testFun(message)) {
				singleBreakpoint();
			}
		}

		public Severity getSeverity() {
			return severity;
		}

		public void setSeverity(Severity severity) {
			this.severity = severity;
		}
		
		public String getMessage() {
			return message;
		}

		public void setMessage(String message) {
			this.message = message;
		}

		public EObject getTarget() {
			return target;
		}

		public void setTarget(EObject target) {
			this.target = target;
		}
		
		public EStructuralFeature getFeature() {
			return feature;
		}

		public void setFeature(EStructuralFeature feature) {
			this.feature = feature;
		}

		public String getIssueCode() {
			return issueCode;
		}

		@Override
		public String toString() {
			return "ValidationIssue [severity=" + severity + ", message=" + message + ", issueCode=" + issueCode
					+ ", target=" + target + "]";
		}

	}

	public void accept(ValidationIssue trace);
	
	public static final class ListBasedValidationIssueAcceptor implements IValidationIssueAcceptor {

		private List<ValidationIssue> traces = Lists.newArrayList();

		@Override
		public void accept(ValidationIssue trace) {
			traces.add(trace);
		}

		public List<ValidationIssue> getTraces() {
			return traces;
		}

		public List<ValidationIssue> getTraces(final Severity severity) {
			return Lists.newArrayList(Iterables.filter(traces, new Predicate<ValidationIssue>() {
				@Override
				public boolean apply(ValidationIssue input) {
					return input.getSeverity() == severity;
				}
			}));
		}

	}

}
