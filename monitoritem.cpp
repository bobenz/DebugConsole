// MonitorItem.cpp
#include "MonitorItem.h"
#include <QMetaProperty>

MonitorItem* MonitorItem::s_instance = nullptr;

MonitorItem::MonitorItem(QQuickItem *parent) : QQuickItem(parent) {
    s_instance = this;
    qInstallMessageHandler(MonitorItem::qtMessageHandler);
}

MonitorItem::~MonitorItem() {
    qInstallMessageHandler(nullptr); // Restore default handler
    s_instance = nullptr;
}

void MonitorItem::qtMessageHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg) {
    if (s_instance) {
        s_instance->handleMessage(type, context, msg);
    } else {
        // Fallback if item is destroyed
        fprintf(stderr, "%s\n", msg.toLocal8Bit().constData());
    }
}

void MonitorItem::handleMessage(QtMsgType type, const QMessageLogContext &context, const QString &msg) {
    QString cat = QString::fromLatin1(context.category);
    
    // REPLACE dots with underscores to match QML property naming (e.g., "app.net" -> "app_net")
    QString propName = QString(cat).replace(".", "_");

    // DYNAMIC FILTER: Walk up the QObject tree using the QMetaObject system
    bool filterEnabled = false;
    QByteArray propBytes = propName.toUtf8();
    
    QObject *node = this;
    while (node) {
        const QMetaObject *meta = node->metaObject();
        int propIndex = meta->indexOfProperty(propBytes.constData());
        
        if (propIndex != -1) {
            filterEnabled = meta->property(propIndex).read(node).toBool();
            break;
        } else if (node->dynamicPropertyNames().contains(propBytes)) {
            filterEnabled = node->property(propBytes.constData()).toBool();
            break;
        }
        node = node->parent();
    }

    if (filterEnabled) {
        // Intercepted: Emit to QML
        emit newMessage(cat, (int)type, msg);
    } else {
        // Standard Output: Everything else goes to regular console
        fprintf(stderr, "[%s] %s\n", context.category, msg.toLocal8Bit().constData());
    }
}

QStringList MonitorItem::getCategories() const {
    QStringList list;
    QObject *node = this->parent();
    while (node) {
        const QMetaObject *meta = node->metaObject();
        int offset = meta->propertyOffset();
        for (int i = offset; i < meta->propertyCount(); ++i) {
            QMetaProperty p = meta->property(i);
            if (p.userType() == QMetaType::Bool || p.type() == QVariant::Bool) {
                QString pName = QString::fromUtf8(p.name());
                if (!list.contains(pName)) list << pName;
            }
        }
        for (const QByteArray &dynProp : node->dynamicPropertyNames()) {
            if (node->property(dynProp.constData()).type() == QVariant::Bool) {
                QString pName = QString::fromUtf8(dynProp);
                if (!list.contains(pName)) list << pName;
            }
        }
        node = node->parent();
    }
    return list;
}