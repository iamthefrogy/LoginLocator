<h1 align="center">LoginLocator
<h1 align="center">
<a href="https://github.com/iamthefrogy/LoginLocator"><img src="https://i.ibb.co/S6hyRqM/DALL-E-2024-05-08-16-26-09-Logo-design-for-a-tech-tool-named-Auth-Scan-The-logo-should-feature-a-sty.webp" alt="frogy" height=130px align="centre"></a>
</h1>
LoginLocator is a powerful Bash script designed to detect login interfaces and social media login options on websites. This tool is particularly useful for security professionals, web developers, and anyone interested in understanding authentication mechanisms implemented across various websites.

## Features

- **Login Detection:** Scans websites to identify traditional and OAuth-based login forms.
- **Social Media Integration Detection:** Detects the presence of social media login options like Google, Facebook, LinkedIn, etc.
- **Output Customization:** Outputs results in a CSV file for easy analysis.
- **Domain Scope Handling:** Ensures that redirects within the same domain are followed, but cross-domain redirects are noted and ignored for security.

## How It Works
LoginLocator uses curl to fetch web pages and analyzes the HTML content using regular expressions to detect forms and specific keywords indicative of authentication mechanisms. The script checks for hidden fields often used in secure forms and social media login options.

## Use Cases

- **Corporate Security Teams:** Can use LoginLocator to check their large number of applications to identify how many of them have login interfaces vs. not and prioritize them for pentest/bug-bounty/vulnerability scanning.
- **Individuals:** Enthusiasts or freelance developers can use LoginLocator to check websites for login interfaces to prioritize for pentest/bug-bounty.

## Getting Started

### Prerequisites
- Bash environment (Linux, Mac OS X, or Windows with WSL)
- `curl` must be installed on your machine

### Installation
Clone the repository to your local machine using:
```
https://github.com/iamthefrogy/LoginLocator.git
chmod 777 loginlocator.sh
```
### Usage
- Create a text file named urls.txt and list the URLs to test, each on a new line.
- Run the script:
Clone the repository to your local machine using:
```
./loginlocator.sh
```
