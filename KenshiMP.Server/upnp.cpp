#include "upnp.h"
#include <spdlog/spdlog.h>

#include <WinSock2.h>
#include <WS2tcpip.h>

#include <algorithm>
#include <cctype>
#include <chrono>
#include <sstream>
#include <string>
#include <vector>

namespace kmp {
namespace {

struct HttpUrl {
    std::string host;
    uint16_t port = 80;
    std::string path = "/";
};

struct IGDService {
    std::string controlUrl;
    std::string serviceType;
};

bool EnsureWinsock() {
    WSADATA wsaData;
    return WSAStartup(MAKEWORD(2, 2), &wsaData) == 0;
}

std::string Trim(const std::string& s) {
    size_t begin = 0;
    while (begin < s.size() && std::isspace(static_cast<unsigned char>(s[begin]))) begin++;

    size_t end = s.size();
    while (end > begin && std::isspace(static_cast<unsigned char>(s[end - 1]))) end--;

    return s.substr(begin, end - begin);
}

std::string ToLower(std::string s) {
    std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) {
        return static_cast<char>(std::tolower(c));
    });
    return s;
}

bool StartsWithI(const std::string& s, const std::string& prefix) {
    if (s.size() < prefix.size()) return false;
    return ToLower(s.substr(0, prefix.size())) == ToLower(prefix);
}

std::string XmlTagValue(const std::string& xml, const std::string& tag, size_t start = 0) {
    std::string open = "<" + tag + ">";
    std::string close = "</" + tag + ">";

    size_t begin = xml.find(open, start);
    if (begin == std::string::npos) return "";
    begin += open.size();

    size_t end = xml.find(close, begin);
    if (end == std::string::npos) return "";
    return Trim(xml.substr(begin, end - begin));
}

bool ParseHttpUrl(const std::string& url, HttpUrl& parsed) {
    const std::string prefix = "http://";
    if (!StartsWithI(url, prefix)) return false;

    size_t hostStart = prefix.size();
    size_t pathStart = url.find('/', hostStart);
    std::string hostPort = pathStart == std::string::npos
        ? url.substr(hostStart)
        : url.substr(hostStart, pathStart - hostStart);

    parsed.path = pathStart == std::string::npos ? "/" : url.substr(pathStart);

    size_t colon = hostPort.rfind(':');
    if (colon != std::string::npos) {
        parsed.host = hostPort.substr(0, colon);
        int port = std::atoi(hostPort.substr(colon + 1).c_str());
        parsed.port = port > 0 && port <= 65535 ? static_cast<uint16_t>(port) : 80;
    } else {
        parsed.host = hostPort;
        parsed.port = 80;
    }

    return !parsed.host.empty();
}

std::string BuildAbsoluteUrl(const HttpUrl& base, const std::string& maybeRelative) {
    if (StartsWithI(maybeRelative, "http://")) return maybeRelative;

    std::ostringstream out;
    out << "http://" << base.host;
    if (base.port != 80) out << ":" << base.port;

    if (!maybeRelative.empty() && maybeRelative[0] == '/') {
        out << maybeRelative;
        return out.str();
    }

    std::string dir = base.path;
    size_t slash = dir.rfind('/');
    dir = slash == std::string::npos ? "/" : dir.substr(0, slash + 1);
    out << dir << maybeRelative;
    return out.str();
}

bool SendAll(SOCKET sock, const std::string& data) {
    const char* ptr = data.data();
    int remaining = static_cast<int>(data.size());

    while (remaining > 0) {
        int sent = send(sock, ptr, remaining, 0);
        if (sent <= 0) return false;
        ptr += sent;
        remaining -= sent;
    }

    return true;
}

std::string HttpRequest(const HttpUrl& url, const std::string& request) {
    addrinfo hints{};
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;

    addrinfo* result = nullptr;
    std::string port = std::to_string(url.port);
    if (getaddrinfo(url.host.c_str(), port.c_str(), &hints, &result) != 0 || !result) {
        return "";
    }

    SOCKET sock = INVALID_SOCKET;
    for (addrinfo* ai = result; ai; ai = ai->ai_next) {
        sock = socket(ai->ai_family, ai->ai_socktype, ai->ai_protocol);
        if (sock == INVALID_SOCKET) continue;

        DWORD timeoutMs = 5000;
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, reinterpret_cast<const char*>(&timeoutMs), sizeof(timeoutMs));
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, reinterpret_cast<const char*>(&timeoutMs), sizeof(timeoutMs));

        if (connect(sock, ai->ai_addr, static_cast<int>(ai->ai_addrlen)) == 0) break;

        closesocket(sock);
        sock = INVALID_SOCKET;
    }
    freeaddrinfo(result);

    if (sock == INVALID_SOCKET) return "";

    if (!SendAll(sock, request)) {
        closesocket(sock);
        return "";
    }

    std::string response;
    char buffer[4096];
    for (;;) {
        int received = recv(sock, buffer, sizeof(buffer), 0);
        if (received <= 0) break;
        response.append(buffer, received);
    }

    closesocket(sock);
    return response;
}

std::string HttpGet(const std::string& urlText) {
    HttpUrl url;
    if (!ParseHttpUrl(urlText, url)) return "";

    std::ostringstream request;
    request << "GET " << url.path << " HTTP/1.0\r\n"
            << "Host: " << url.host << ":" << url.port << "\r\n"
            << "Connection: close\r\n\r\n";

    return HttpRequest(url, request.str());
}

std::string HttpPostSoap(const std::string& urlText,
                         const std::string& serviceType,
                         const std::string& action,
                         const std::string& body) {
    HttpUrl url;
    if (!ParseHttpUrl(urlText, url)) return "";

    std::ostringstream request;
    request << "POST " << url.path << " HTTP/1.0\r\n"
            << "Host: " << url.host << ":" << url.port << "\r\n"
            << "Content-Type: text/xml; charset=\"utf-8\"\r\n"
            << "SOAPAction: \"" << serviceType << "#" << action << "\"\r\n"
            << "Content-Length: " << body.size() << "\r\n"
            << "Connection: close\r\n\r\n"
            << body;

    return HttpRequest(url, request.str());
}

bool HttpSucceeded(const std::string& response) {
    return response.find("HTTP/1.1 200") != std::string::npos ||
           response.find("HTTP/1.0 200") != std::string::npos;
}

std::string FindHeaderValue(const std::string& response, const std::string& headerName) {
    std::istringstream lines(response);
    std::string line;
    std::string wanted = ToLower(headerName) + ":";

    while (std::getline(lines, line)) {
        if (!line.empty() && line.back() == '\r') line.pop_back();
        std::string lower = ToLower(line);
        if (lower.rfind(wanted, 0) == 0) {
            return Trim(line.substr(wanted.size()));
        }
    }

    return "";
}

std::vector<std::string> SearchTargets() {
    return {
        "urn:schemas-upnp-org:device:InternetGatewayDevice:1",
        "urn:schemas-upnp-org:service:WANIPConnection:1",
        "urn:schemas-upnp-org:service:WANPPPConnection:1",
        "upnp:rootdevice"
    };
}

std::string DiscoverDeviceDescriptionUrl(const std::string& localIP) {
    if (!EnsureWinsock()) return "";

    sockaddr_in local{};
    local.sin_family = AF_INET;
    local.sin_port = 0;
    inet_pton(AF_INET, localIP.c_str(), &local.sin_addr);

    sockaddr_in multicast{};
    multicast.sin_family = AF_INET;
    multicast.sin_port = htons(1900);
    inet_pton(AF_INET, "239.255.255.250", &multicast.sin_addr);

    for (const std::string& target : SearchTargets()) {
        SOCKET sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
        if (sock == INVALID_SOCKET) continue;

        DWORD timeoutMs = 1200;
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, reinterpret_cast<const char*>(&timeoutMs), sizeof(timeoutMs));
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, reinterpret_cast<const char*>(&timeoutMs), sizeof(timeoutMs));
        setsockopt(sock, IPPROTO_IP, IP_MULTICAST_IF, reinterpret_cast<const char*>(&local.sin_addr), sizeof(local.sin_addr));

        if (bind(sock, reinterpret_cast<sockaddr*>(&local), sizeof(local)) != 0) {
            closesocket(sock);
            continue;
        }

        std::ostringstream request;
        request << "M-SEARCH * HTTP/1.1\r\n"
                << "HOST: 239.255.255.250:1900\r\n"
                << "MAN: \"ssdp:discover\"\r\n"
                << "MX: 2\r\n"
                << "ST: " << target << "\r\n\r\n";

        std::string packet = request.str();
        sendto(sock, packet.data(), static_cast<int>(packet.size()), 0,
               reinterpret_cast<sockaddr*>(&multicast), sizeof(multicast));

        auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(4);
        while (std::chrono::steady_clock::now() < deadline) {
            char buffer[4096];
            sockaddr_in from{};
            int fromLen = sizeof(from);
            int received = recvfrom(sock, buffer, sizeof(buffer) - 1, 0,
                                    reinterpret_cast<sockaddr*>(&from), &fromLen);
            if (received <= 0) break;

            std::string response(buffer, received);
            std::string location = FindHeaderValue(response, "LOCATION");
            if (!location.empty()) {
                closesocket(sock);
                return location;
            }
        }

        closesocket(sock);
    }

    return "";
}

bool FindServiceInDescription(const std::string& location, IGDService& service) {
    HttpUrl base;
    if (!ParseHttpUrl(location, base)) return false;

    std::string response = HttpGet(location);
    if (!HttpSucceeded(response)) return false;

    const std::vector<std::string> serviceTypes = {
        "urn:schemas-upnp-org:service:WANIPConnection:2",
        "urn:schemas-upnp-org:service:WANIPConnection:1",
        "urn:schemas-upnp-org:service:WANPPPConnection:1"
    };

    for (const std::string& serviceType : serviceTypes) {
        size_t pos = 0;
        while ((pos = response.find("<service>", pos)) != std::string::npos) {
            size_t end = response.find("</service>", pos);
            if (end == std::string::npos) break;

            std::string block = response.substr(pos, end - pos);
            if (block.find(serviceType) != std::string::npos) {
                std::string control = XmlTagValue(block, "controlURL");
                if (!control.empty()) {
                    service.controlUrl = BuildAbsoluteUrl(base, control);
                    service.serviceType = serviceType;
                    return true;
                }
            }

            pos = end + 10;
        }
    }

    return false;
}

bool DiscoverIGDService(const std::string& localIP, IGDService& service) {
    std::string location = DiscoverDeviceDescriptionUrl(localIP);
    if (location.empty()) {
        spdlog::warn("UPnP: No IGD device responded to SSDP discovery");
        return false;
    }

    spdlog::info("UPnP: Found gateway description at {}", location);
    if (!FindServiceInDescription(location, service)) {
        spdlog::warn("UPnP: Gateway did not advertise WANIPConnection/WANPPPConnection");
        return false;
    }

    spdlog::info("UPnP: Using {} at {}", service.serviceType, service.controlUrl);
    return true;
}

std::string SoapEnvelope(const std::string& action,
                         const std::string& serviceType,
                         const std::string& innerXml) {
    std::ostringstream body;
    body << "<?xml version=\"1.0\"?>\r\n"
         << "<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" "
         << "s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">\r\n"
         << "<s:Body>\r\n"
         << "<u:" << action << " xmlns:u=\"" << serviceType << "\">\r\n"
         << innerXml
         << "</u:" << action << ">\r\n"
         << "</s:Body>\r\n"
         << "</s:Envelope>\r\n";
    return body.str();
}

} // namespace

std::string UPnPMapper::GetLocalIP() {
    if (!EnsureWinsock()) return "127.0.0.1";

    SOCKET sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (sock == INVALID_SOCKET) return "127.0.0.1";

    sockaddr_in target{};
    target.sin_family = AF_INET;
    target.sin_port = htons(80);
    inet_pton(AF_INET, "8.8.8.8", &target.sin_addr);

    if (connect(sock, reinterpret_cast<sockaddr*>(&target), sizeof(target)) != 0) {
        closesocket(sock);
        return "127.0.0.1";
    }

    sockaddr_in local{};
    int localLen = sizeof(local);
    if (getsockname(sock, reinterpret_cast<sockaddr*>(&local), &localLen) != 0) {
        closesocket(sock);
        return "127.0.0.1";
    }

    char ipStr[INET_ADDRSTRLEN] = {};
    inet_ntop(AF_INET, &local.sin_addr, ipStr, sizeof(ipStr));
    closesocket(sock);

    return ipStr[0] ? ipStr : "127.0.0.1";
}

bool UPnPMapper::AddMapping(uint16_t externalPort, uint16_t internalPort,
                            const std::string& protocol, const std::string& description) {
    spdlog::info("UPnP: Attempting to map port {} ({})...", externalPort, protocol);

    std::string localIP = GetLocalIP();
    spdlog::info("UPnP: Local IP is {}", localIP);

    IGDService service;
    if (!DiscoverIGDService(localIP, service)) {
        spdlog::warn("UPnP: Players will need manual forwarding for port {}", externalPort);
        return false;
    }

    std::ostringstream inner;
    inner << "<NewRemoteHost></NewRemoteHost>\r\n"
          << "<NewExternalPort>" << externalPort << "</NewExternalPort>\r\n"
          << "<NewProtocol>" << protocol << "</NewProtocol>\r\n"
          << "<NewInternalPort>" << internalPort << "</NewInternalPort>\r\n"
          << "<NewInternalClient>" << localIP << "</NewInternalClient>\r\n"
          << "<NewEnabled>1</NewEnabled>\r\n"
          << "<NewPortMappingDescription>" << description << "</NewPortMappingDescription>\r\n"
          << "<NewLeaseDuration>0</NewLeaseDuration>\r\n";

    std::string response = HttpPostSoap(
        service.controlUrl,
        service.serviceType,
        "AddPortMapping",
        SoapEnvelope("AddPortMapping", service.serviceType, inner.str()));

    if (!HttpSucceeded(response)) {
        spdlog::warn("UPnP: Failed to add port mapping. Router response: {}",
                     response.substr(0, std::min<size_t>(response.size(), 256)));
        return false;
    }

    m_mapped = true;
    m_mappedPort = externalPort;
    m_mappedProtocol = protocol;
    m_controlUrl = service.controlUrl;
    m_serviceType = service.serviceType;

    spdlog::info("UPnP: Successfully mapped port {} -> {}:{} ({})",
                 externalPort, localIP, internalPort, protocol);

    std::string extIP = GetExternalIP();
    if (!extIP.empty()) {
        spdlog::info("UPnP: External IP is {}", extIP);
    }

    return true;
}

bool UPnPMapper::RemoveMapping(uint16_t externalPort, const std::string& protocol) {
    if (!m_mapped) return true;

    spdlog::info("UPnP: Removing port mapping {} ({})...", externalPort, protocol);

    IGDService service{m_controlUrl, m_serviceType};
    if (service.controlUrl.empty() || service.serviceType.empty()) {
        if (!DiscoverIGDService(GetLocalIP(), service)) return false;
    }

    std::ostringstream inner;
    inner << "<NewRemoteHost></NewRemoteHost>\r\n"
          << "<NewExternalPort>" << externalPort << "</NewExternalPort>\r\n"
          << "<NewProtocol>" << protocol << "</NewProtocol>\r\n";

    std::string response = HttpPostSoap(
        service.controlUrl,
        service.serviceType,
        "DeletePortMapping",
        SoapEnvelope("DeletePortMapping", service.serviceType, inner.str()));

    if (HttpSucceeded(response)) {
        spdlog::info("UPnP: Port mapping removed");
        m_mapped = false;
        return true;
    }

    spdlog::warn("UPnP: Failed to remove mapping. Router response: {}",
                 response.substr(0, std::min<size_t>(response.size(), 256)));
    return false;
}

std::string UPnPMapper::GetExternalIP() {
    IGDService service{m_controlUrl, m_serviceType};
    if (service.controlUrl.empty() || service.serviceType.empty()) {
        if (!DiscoverIGDService(GetLocalIP(), service)) return "";
    }

    std::string response = HttpPostSoap(
        service.controlUrl,
        service.serviceType,
        "GetExternalIPAddress",
        SoapEnvelope("GetExternalIPAddress", service.serviceType, ""));

    if (!HttpSucceeded(response)) return "";
    return XmlTagValue(response, "NewExternalIPAddress");
}

} // namespace kmp
