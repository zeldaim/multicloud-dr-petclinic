package org.springframework.samples.petclinic.system;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
class WelcomeController {

	@Value("${project.env.name:Primary (AWS)}")
	private String envName;

	@GetMapping("/")
	public String welcome(Model model) {
		model.addAttribute("envName", envName);
		return "welcome";
	}

}
